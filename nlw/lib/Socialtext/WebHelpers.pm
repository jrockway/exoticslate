# @COPYRIGHT@
package Socialtext::WebHelpers;

use strict;
use warnings;

use Socialtext::String;
use Socialtext::URI;
use URI::Escape ();
use Apache::Constants qw(FORBIDDEN REDIRECT);

my $SupportClass;
my %Roles;
BEGIN {
    $SupportClass =
        ( ( $ENV{MOD_PERL} && eval { require Apache::Request } and not $@ )
          ? 'Socialtext::WebHelpers::Apache'
          : 'Socialtext::WebHelpers::CGIpm'
        );

    eval "require $SupportClass";
    die $@ if $@;

    %Roles = (
        base    => [ qw(
            uri_escape
            uri_unescape
            html_escape
            html_unescape
        ) ],
        headers => [ qw(
            apr
            redirect
            print
            set_all
            _get
            _value
        ) ],
        cgi => [ qw(
            apr
            defined
            names
            full_uri
            full_uri_with_query
            _full_uri
            path_info
            query_string
            _get_cgi_param
            _get_upload
        ) ],
    );
}

sub import {
    shift;
    my @roles = @_;

    my $caller = caller;

    my %exported;
    for my $role (@roles) {
        $role =~ s/^://;
        next unless $Roles{$role};

        for my $meth ( @{ $Roles{$role} } ) {
            next if $exported{$meth};

            my $class = __PACKAGE__->can($meth) ? __PACKAGE__: $SupportClass;
            {
                no strict 'refs';
                *{"$caller\::$meth"} = \&{"$class\::$meth"};
            }

            $exported{$meth} = 1;
        }
    }
}

# Base role

sub uri_escape {
    my $self = shift;
    return URI::Escape::uri_escape_utf8(shift);
}

sub uri_unescape {
    my $self = shift;
    my $data = shift;
    $data = URI::Escape::uri_unescape($data);
    return $self->utf8_decode($data);
}

sub html_escape {
    my $self = shift;
    return Socialtext::String::html_escape(@_);
}

sub html_unescape {
    my $self = shift;
    return Socialtext::String::html_unescape(@_);
}

sub redirect {
    my $class = shift;
    my $uri = (@_ == 1 ? shift : Socialtext::URI::uri(@_));

    my $r = Apache::Request->instance( Apache->request );
    $r->method('GET');
    $r->headers_in->unset('Content-length');

    $r->err_headers_out->add( Location => $uri );
    $r->status ( REDIRECT );

    $r->send_http_header;
}

sub abort_forbidden {
    my $self       = shift;
    my $r = Apache::Request->instance( Apache->request );

    $r->method('GET');
    $r->headers_in->unset('Content-length');
    $r->status(FORBIDDEN);

    Socialtext::WebApp::Exception::Forbidden->throw();
}
1;
