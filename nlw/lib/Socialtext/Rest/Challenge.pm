# @COPYRIGHT@
package Socialtext::Rest::Challenge;
use strict;
use warnings;

use base 'Socialtext::Rest';
use Socialtext::Challenger;
use Socialtext::HTTP ':codes';
use URI::Escape qw(uri_unescape);

sub handler {
    my ( $self, $rest ) = @_;

    # we use query string to avoid the processing that's done
    # to make official URIs. This way no data is lost:
    # REVIEW: Challener::STLogin does not escape what it puts
    # on its query string.
    # REVIEW: this depends on a bunch CGI.pm whooey that may
    # not be reliable.
    my $uri = $rest->query->query_string();
    $uri =~ s/^keywords=//;

    eval {Socialtext::Challenger->Challenge( redirect => uri_unescape($uri) );};

    if ( my $e = $@ ) {
        if ( Exception::Class->caught('Socialtext::WebApp::Exception::Redirect') )
        {
            my $location = $e->message;
            $rest->header(
                -status   => HTTP_302_Found,
                -Location => $location,
            );
            return '';
        }
    }
    $self->rest->header(
        -status => HTTP_500_Internal_Server_Error,
    );
    return 'Challenger Did not Redirect';
}

1;

__END__

=head1 NAME

Socialtext::Rest::Challenge - Provides a handler() sub for challenges

=head1 SYNOPSIS

  <Location /challenge>
      PerlHandler  +Socialtext::Handler::Rest
  </LocationMatch>

A path must be added to uri_map.yaml.


=cut
