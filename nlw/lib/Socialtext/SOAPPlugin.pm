# @COPYRIGHT@
package Socialtext::SOAPPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use Class::Field qw( const );
use SOAP::Lite;


const class_title => 'generic soap retrieval';
sub class_id { 'soap_access' }

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(template => 'base_soap.html');
    $registry->add(wafl => soap => 'Socialtext::SOAP::Wafl');
}

sub soap {
    my $self = shift;
    my $wsdl = shift;
    my $method = shift;
    my $args_list = shift;
    my $soap;
    my $result;

    eval {
        $soap = SOAP::Lite->service($wsdl);
        $result = $soap->$method(@$args_list);
    };
    if ($@) {
        return {error => (split(/\n/,$@))[0]};
    }
    return $result;
}

package Socialtext::SOAP::Wafl;

use Socialtext::Formatter::WaflPhrase;
use base 'Socialtext::Formatter::WaflPhraseDiv';

use YAML ();

# XXX move most of this up into the top package
# and break it up so tests can access it and 
# some of the soap stuff can be wrapped in evals
# to trap errors (which cause death at the moment)

sub html {
    my $self = shift;
    my ($wsdl, $method, @args) = split(' ', $self->arguments);
    return $self->walf_error
        unless $method;

    my $soap_access = $self->hub->soap_access;
    my $result = $soap_access->soap($wsdl, $method, \@args);

    return $self->pretty($soap_access, $result);
}

sub pretty {
    my $self = shift;
    my $soap_access = shift;
    my $results = shift;
    $self->hub->template->process('base_soap.html',
        soap_class  => $soap_access->class_id,
        soap_output => YAML::Dump($results),
    );
}

1;

