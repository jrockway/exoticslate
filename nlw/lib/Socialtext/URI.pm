package Socialtext::URI;

use strict;
use warnings;

use Socialtext::AppConfig;
use URI::FromHash;


sub uri {
    URI::FromHash::uri( _scheme(), _host(), _port(), @_ );
}

sub uri_object {
    URI::FromHash::uri( _scheme(), _host(), _port(), @_ );
}

sub _scheme {
    return ( scheme => 'http' );
}

sub _host {
    return ( host => Socialtext::AppConfig->web_hostname() );
}

sub _port {
    my $custom_port = Socialtext::AppConfig->custom_http_port();
    return unless $ENV{NLW_FRONTEND_PORT} or $custom_port;

    return ( port => $custom_port || $ENV{NLW_FRONTEND_PORT} );
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
