# @COPYRIGHT@
package Socialtext::Handler::WSDL;
use strict;
use warnings;
use Apache::Constants qw(NOT_FOUND OK);
use File::Slurp qw(slurp);
use File::Spec::Functions qw(catfile);
use Socialtext::AppConfig;
use Socialtext::URI;

sub handler ($$) {
    my ( $class, $r ) = @_;
    return NOT_FOUND unless $r->uri =~ m{^.*/(.+)\.wsdl$};
    my $ver = $1;

    my $share = Socialtext::AppConfig->code_base();
    my $file = catfile( $share, "wsdl", "$ver.wsdl" );
    return NOT_FOUND unless -e $file and -r _;

    my $wsdl = eval { slurp($file) };
    return NOT_FOUND unless defined $wsdl;

    my $soap_server = Socialtext::WebHelpers::Apache->base_uri();
    $soap_server .= "/soap/$ver/";
    $wsdl =~ s/\@SOAP_SERVER\@/$soap_server/g;

    $r->send_http_header( 'text/xml' );
    $r->print($wsdl);
    return OK;
}

1;
__END__

=head1 NAME

Socialtext::Handler::WSDL - Generate WSDL files for SOAP.

=head1 DESCRIPTION

When someone does GET /wsdl/$ver.wsdl that causes $ver.wsdl to be slurped in
from /usr/share/nlw/wsdl/$ver.wsdl.  The SOAP server in the WSDL is set
dynamically.  The resultant WSDL is returned.

=cut
