# @COPYRIGHT@
package Socialtext::Rest::WSDL;
use strict;
use warnings;

use base 'Socialtext::Rest';

use Socialtext::HTTP ':codes';
use File::Slurp qw(slurp);
use File::Spec::Functions qw(catfile);
use Socialtext::AppConfig;

sub GET {
    my ($self, $rest ) = @_;

    my $wsdl_file = $self->wsdl;

    if ($wsdl_file =~ m{(.+)\.wsdl$}) {
        my $ver = $1;

        my $share = Socialtext::AppConfig->code_base();
        my $file = catfile( $share, "wsdl", $wsdl_file );
        if (-e $file and -r _) {

            my $wsdl = eval { slurp($file) };
            if (defined $wsdl) {

                my $soap_server = $rest->query->url(-base => 1);
                $soap_server .= "/soap/$ver/";
                $wsdl =~ s/\@SOAP_SERVER\@/$soap_server/g;

                $rest->header(
                    -type => 'text/xml',
                    -status => HTTP_200_OK,
                );

                return $wsdl;
            }
        }
    }

    $rest->header(
        -status => HTTP_404_Not_Found,
    );

    return '';
}

1;
__END__

=head1 NAME

Socialtext::Rest::WSDL - Generate WSDL files for SOAP.

=head1 DESCRIPTION

When someone does GET /wsdl/$ver.wsdl that causes $ver.wsdl to be slurped in
from /usr/share/nlw/wsdl/$ver.wsdl.  The SOAP server in the WSDL is set
dynamically.  The resultant WSDL is returned.

=cut
