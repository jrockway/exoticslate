package Apache::Request;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Exporter';
our @EXPORT_OK = qw/get_log_reasons/;

our @LOG_MSGS;
our %HEADERS;
our %PARAMS;

sub new {
    my $class = shift;
    my $self = (@_ == 1 ? shift : { @_ });
    bless $self, $class;
}

sub method           { }
sub headers_in       {shift}
sub err_headers_out  {shift}
sub unset            { }
sub add              { $HEADERS{$_[1]} = $_[2] }
sub status           { }
sub send_http_header { }

sub instance {
    new(@_);
}

sub param {
    my $self  = shift;
    my $field = lc(shift);
    if ($field) {
        if (@_) {
            $PARAMS{$field} = shift;
        }
        return $PARAMS{$field};
    }
    return sort keys %PARAMS;
}

# This is getting so deep
sub parsed_uri {
    my $self = shift;
    return Apache::URI->new(
        hostname => 'www.example.com',
        scheme   => 'http',
    );
}

sub hostname {
    return 'example.com';
}

# this can be extended to return more values depending on the key
my %DIR_CONFIG = (
    NLWHTTPSRedirect => 1,
);
sub dir_config {
    my $self = shift;
    my $key = shift;

    return $DIR_CONFIG{$key};
}

sub connection { $_[0] }

sub user {
    $_[0]->{connection_user} = $_[1] if @_ > 1;
    return $_[0]->{connection_user};
}

sub header_in {
    my $self = shift;
    my $key  = shift;

    return $self->{$key};
}

sub header_out {
    my $self = shift;
    my $key  = shift;
    my $val  = shift;
    $self->{$key} = $val if (defined $val);
    return $self->{$key};
}

sub uri { $_[0]->{uri} }

######

sub log_reason {
    my $self = shift;
    push @LOG_MSGS, @_;
}

sub get_log_reasons {
    my @msgs = @LOG_MSGS;
    @LOG_MSGS = ();
    return @msgs;
}

######
package Apache::URI;

sub new {
    my ($class, %opts) = @_;
    my $self = {
        scheme   => 'http',
        hostname => 'localhost',
        path     => '/',
        query    => '',
        %opts
    };
    bless $self, $class;
}

sub hostname { $_[0]->{hostname} }
sub query    { $_[0]->{query} }
sub path     { $_[0]->{path} }

sub scheme {
    my $self = shift;
    $self->{scheme} = shift if @_;
    return $self->{scheme};
}

sub unparse {
    my $self = shift;
    return $self->scheme . '://'
        . $self->hostname
        . $self->path
        . ( $self->query ? '?' . $self->query : '' );
}


1;
