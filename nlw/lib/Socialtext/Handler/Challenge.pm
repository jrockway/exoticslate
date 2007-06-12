# @COPYRIGHT@
package Socialtext::Handler::Challenge;
use strict;
use warnings;

use base 'Socialtext::Handler';
use Socialtext::Challenger;
use URI::Escape qw(uri_unescape);

sub handler {
    my $r = shift;

    my $uri = $r->parsed_uri->unparse;
    $uri =~ s#^/challenge\??##g;
    Socialtext::Challenger->Challenge( redirect => uri_unescape($uri) );

}

1;

__END__

=head1 NAME

Socialtext::Handler::Challenge - Provides a handler() sub for challenges

=head1 SYNOPSIS

  <Location /challenge>
      PerlHandler  +Socialtext::Handler:Challenge
  </LocationMatch>


=cut
