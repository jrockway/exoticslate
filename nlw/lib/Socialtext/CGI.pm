# @COPYRIGHT@
package Socialtext::CGI;
use strict;
use warnings;

use base 'Socialtext::Base', 'Exporter';

our @EXPORT = qw(cgi);

use Socialtext::WebHelpers ':cgi';


sub class_id { 'cgi' }

my $all_params_by_class = {};

sub init {
    my $self = shift;
    $self->add_params(qw(action page_name));
}

sub cgi {
    my $package = caller;
    my ($field, $is_upload, @flags);
    for (@_) {
        if ($_ eq '-upload') {
            $is_upload = 1;
            next;
        }
        (push @flags, $1), next if /^-(\w+)$/;
        $field ||= $_;
    }
    die "Cannot apply flags to upload field ($field)" if $is_upload and @flags;
    $all_params_by_class->{$package}->{$field} = 1;
    _install_field($package, $field, $is_upload, \@flags);
}

sub _install_field {
    my ($package, $field, $is_upload, $flags) = @_;
    # Go ahead, I dare you.
    # warn "Socialtext::CGI::_install_field: $package->can('$field') already exists!\n"
    #   if $package->can($field);

    my $field_method =
          @{$flags}  ? _make_flags_method( $field, $flags )
        : $is_upload ? _make_upload_method($field)
        :              _make_default_method($field);

    {
        no strict 'refs';
        no warnings 'redefine';
        *{"$package\::$field"} = $field_method;
    }
}

sub _make_upload_method  {
    my ($field) = @_;

    sub {
        my $self = shift;
        if (wantarray) {
            my @uploads = $self->_get_upload($field);
            return @uploads;
        } else {
            my $upload = $self->_get_upload($field);
            return $upload;
        }
    }
}

sub _make_flags_method  {
    my ( $field, $flags ) = @_;

    sub {
        my $self = shift;
        die "Setting CGI params not implemented" if @_;
        my $param = $self->_get_raw($field);
        for my $flag (@{$flags}) {
            my $method = "_${flag}_filter";
            $self->$method($param);
        }
        return $param;
    }
}

sub _make_default_method  {
    my ($field) = @_;
    sub {
        my $self = shift;
        die "Setting CGI params not implemented" if @_;
        $self->_get_raw($field);
    }
}

cgi 'button';

sub add_params {
    my $self = shift;
    my $class = ref($self);
    foreach my $field (@_) {
        $all_params_by_class->{$class}->{$field} = 1;
    }
}

sub all {
    my $self = shift;
    my $class = ref($self);
    map { ($_, scalar $self->$_) } keys(%{$all_params_by_class->{$class}});
}

sub vars {
    my $self = shift;
    map { my @val = $self->_get_raw($_);
          $_ => @val > 1 ? \@val : $val[0] } $self->names;
}

sub _trim_filter {
    $_[1] =~ s/^\s*(.*?)\s*$/$1/mg;
    $_[1] =~ s/\s+/ /g;
}

sub _newlines_filter {
    if (length $_[1]) {
        $_[1] =~ s/\015\012/\n/g;
        $_[1] =~ s/\015/\n/g;
        $_[1] .= "\n"
          unless $_[1] =~ /\n\z/;
    }
}

sub _get_raw {
    my $self = shift;
    my $field = shift;

    my @values;
    if (defined(my $value = $self->{$field})) {
        @values = ref($value)
          ? @$value
          : $value;
    }
    else {
        @values = $self->_get_cgi_param($field);

        $self->utf8_decode($_)
          for grep { defined } @values;

        $self->{$field} = @values > 1
          ? \@values
          : $values[0];
    }

    return wantarray
      ? @values
      : defined $values[0]
        ? $values[0]
        : '';
}

sub action {
    my $self = shift;
    if (@_) {
        $self->{action} = shift;
        return $self;
    }
    my $action = $self->_get_cgi_param('action') || '';
    $action = '' if $action =~ /\W/;
    return 'display' if $self->query_string && ! $action;
    return $action || $self->_truly_default_action;
}

sub _truly_default_action {
    my $self = shift;

    # A guest user can't have a personal homepage, says adina.
    # I suspect they just can't have a watchlist. -- cwest
    # TODO Get this finalized.
    $self->hub->current_user->is_guest ? 'display' : 'homepage';
}

sub page_name {
    my $self = shift;
    return $self->{page_name} = shift if @_;
    return $self->{page_name}
      if defined $self->{page_name};
    my $page_name = $self->_get_cgi_param('page_name');
    $page_name = $self->uri_unescape($page_name);

    unless (defined $page_name) {
        my $query_string = $self->query_string();

        # Deal with CGI.pm madness (because we use it when testing)
        if ( defined $query_string ) {
            $query_string =~ s/;?keywords=/ /g;
            $page_name = $self->uri_unescape($query_string)
                unless $query_string =~ /=/;
        }
        # maybe the page is on path_info
        else {
            my ($page_id)
                = ( $self->path_info()
                    =~ m{/page/[^\/]+/(?:member/)?([^?]+)\??.*$} );
            $page_name = $self->uri_unescape($page_id);
        }
    }

    $self->{page_name} =
      defined($page_name)
      ? $page_name
      : $self->default_page_name;

    return $self->{page_name};
}

# XXX is it possible to get the hub out of this method?
sub default_page_name {
    my $self = shift;
    XXX $self unless $self->hub;
    my %vars = $self->vars;
    return
        $vars{title} ||
        $vars{page_id} ||
        $self->hub->current_workspace->title ||
        '';
}

sub _clean_filter {
    $_[1] =~ s/^\s*(.*?)\s*$/$1/mg;
    $_[1] =~ s/\s+/ /g;
    $_[1] =~ s/"/'/g;
}

sub _clean_path_filter {
    $_[1] =~ s/\.\.\///g;
}

sub _html_escape_filter {
    my $self = shift;
    $_[1] = $self->html_escape($_[1]);
}

# protect against <script> attacks
sub _html_clean_filter {
    $_[1] =~ s/[<>]/ /g;
}

# Detect if this is a request by XMLHttpRequest.
# Follows the request header set by prototype.js
sub is_xhr {
    my $self = shift;
    my $xrw = $self->apr->header_in( 'X-Requested-With' );

    return $xrw && ( $xrw eq 'XMLHttpRequest' );
}

1;

