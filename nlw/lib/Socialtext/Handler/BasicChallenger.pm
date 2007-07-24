package Socialtext::Handler::BasicChallenger;
# @COPYRIGHT@

use strict;
use warnings;

=head1 NAME

Socialtext::Handler::BasicChallenger
- When needing to cause auth, cause Basic Auth

=head1 DESCRIPTION

Most parts of the Socialtext application use the standard
L<Socialtext::Challenger> plugin system.  However, some parts prefer to use
HTTP Basic Auth, and those handlers are written to use this class as a base
class, rather than L<Socialtext::Handler>.

Despite the name given to this class, it is not a standard
L<Socialtext::Challenger> plugin.

This system will be modified in a future release so that you can configure a
distinct Challenger for each of the Web Application, Syndication, and REST API
subsystems.

This class overrides L<Socialtext::Handler/challenge> to avoid the
C<Socialtext::Challenger> system.

=head1 SEE ALSO

L<Socialtext::Handler/challenge()>,
L<Socialtext::Handler/handler()>, and
L<Socialtext::Handler/get_nlw()>.

=cut

use base 'Socialtext::Handler';

use Apache::Constants qw(OK AUTH_REQUIRED);
use Socialtext::HTTP ':codes';

# Inform the client that we'd like them to use basic
# authentication in the realm Socialtext. We do a
# manual header_out because we don't want to rely
# on Apache configuration which $r->note_basic_auth_failure
# requires.
sub challenge {
    my $class   = shift;
    my %p       = @_;
    my $request = $p{request};

    $request->status_line(HTTP_401_Unauthorized);
    $request->header_out('WWW-Authenticate' => 'Basic realm="Socialtext"');
    $request->send_http_header;
    return AUTH_REQUIRED
}

1;
