package Socialtext::URI;
#@COPYRIGHT@

use strict;
use warnings;

use Socialtext::AppConfig;
use Socialtext::HTTPPorts qw(SSL_PORT_DIFFERENCE);
use URI::FromHash;

our $default_scheme = 'http';
our $CachedURI;

sub uri {
    # Optimize for the common case: Socialtext::URI::uri(path => ...).
    if (@_ == 2 and $_[0] eq 'path') {
        $CachedURI ||= URI::FromHash::uri_object( _scheme_host_port() );
        $CachedURI->path($_[1]);
        return $CachedURI->as_string;
    }

    URI::FromHash::uri( _scheme_host_port(), @_ );
}

sub uri_object {
    URI::FromHash::uri_object( _scheme_host_port(), @_ );
}

sub _scheme_host_port {
    my $scheme = _scheme();
    return (
        scheme => $scheme,
        _host(),
        (($scheme eq 'http') ? _http_port() : _https_port())
    );
}

sub _scheme {
    my $apr    = _apr();
    my $scheme = $default_scheme;

    if ($apr) {
        # FIXME: we should look in the ENV here not the apache
        # dir config
        $scheme = $ENV{NLWHTTPSRedirect} ? 'https' : 'http';
    }
    return ( scheme => $scheme );
}

sub _host {
    return ( host => Socialtext::AppConfig->web_hostname() );
}

sub _port {
    if (_scheme() eq 'http') {
        return _http_port();
    }
    else {
        return _https_port();
    }
}

sub _http_port {
    my $custom_port = Socialtext::AppConfig->custom_http_port();
    return () unless ($ENV{NLW_FRONTEND_PORT} or $custom_port);
    return ( port => ( $custom_port || $ENV{NLW_FRONTEND_PORT} ) );
}

sub _https_port {
    # NLW_FRONTEND_PORT only set in dev-env when there
    # is a front and backend
    if ($ENV{NLW_FRONTEND_PORT}) {
        return ( port => ( $ENV{NLW_FRONTEND_PORT} + SSL_PORT_DIFFERENCE ));
    }

    # set no special port if the user is using custom_http_port
    # current use cases define no special behavior for SSL in
    # those circumstances
    return () if Socialtext::AppConfig->custom_http_port();

    # sigh under some circumstances in tests when using a mock
    # Apache::Request we can reach here.
    return ();
}

sub _apr {
    my $apr;
    eval {
        require Apache;
        require Apache::Request;
        $apr = Apache::Request->instance( Apache->request );
    };
    return undef if $@;
    return $apr;
}

1;

__END__

=head1 NAME

Socialtext::Hostname - URI-making functions for socialtext

=head1 SYNOPSIS

  use Socialtext::URI;

  my $uri = Socialtext::URI::uri(
      path  => '/path/to/thing',
      query => { foo => 1 },
  );

=head1 DESCRIPTION

This module provides a simple wrapper around C<URI::FromHash> to
provide the correct scheme, host, and port for URIs, based on the
Socialtext application config.

=head1 FUNCTIONS

This module wraps the C<uri()> and C<uri_object()> functions from the
C<URI::FromHash> module, and provides the same API as that module.

However, it supplies default "scheme", "host", and "port" parameters
for you based on the Socialtext application conifg and your
environment.

You can, however, override any of these parameters when calling a
function.

=head2 scheme

For now, this is always "http". This is included to allow for the
possibility of a configuraiton to force all request to "https" in the
future.

=head2 host

This will be C<< Socialtext::AppConfig->web_hostname() >>.

=head2 port

If the C<NLW_FRONTEND_PORT> variable is set, it will be
used. Otherwise no "port" is provided.

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2006 Socialtext, Inc., All Rights Reserved.

=cut
