# @COPYRIGHT@ 
package Socialtext::SOAPGoogle;
use strict;
use warnings;
use base 'Socialtext::SOAPPlugin';
use Class::Field qw( const );
const wsdl => 'http://api.google.com/GoogleSearch.wsdl';
const method => 'doGoogleSearch';
const limit => 10;
const class_title => 'google soap retrieval';

sub class_id { 'googlesoap' }
const default_google_key => 'CTSnKAJQFHJCcVYPh0q0FD56rtcxpIHI';


sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(wafl => googlesoap => 'Socialtext::SOAP::Google::Wafl');
}

sub key {
    my $self = shift;
    # XXX - this is never true, there is no Workspace.google_api_key
    # field - does anyone use this? Shouldn't it just be app config
    # instead?
    ($self->hub->current_workspace->can('google_api_key'))
      ? $self->hub->current_workspace->google_api_key
      : $self->default_google_key;
}

sub get_result {
    my $self = shift;
    my $query = shift;
    my $google_key = $self->key;
    return { error => 'no google key' }
        unless $google_key;
    my $result = $self->soap(
        $self->wsdl,
        $self->method,
        [
        $google_key,
        $query,
        0,
        $self->limit,
        'true', '', 'false', '', 'UTF-8', 'UTF-8'
        ]
    );
}

package Socialtext::SOAP::Google::Wafl;

use base 'Socialtext::SOAP::Wafl';
use Socialtext::l10n qw(loc);

sub html {
    my $self = shift;
    my $query = $self->arguments;
    return $self->syntax_error unless ($query);

    my $googlesoap = $self->hub->googlesoap;
    my $result = $googlesoap->get_result($query);

    return $self->pretty($googlesoap, $query, $result);
}

sub pretty {
    my $self = shift;
    my $googlesoap = shift;
    my $query = shift;
    my $result = shift;
    $self->hub->template->process('wafl_box.html',
        soap_class  => $googlesoap->class_id,
        query => $query,
        wafl_title => loc('Search for "[_1]"', $query),
        wafl_link => "http://www.google.com/search?q=$query",
        items => $result->{resultElements},
        error => $result->{error},
    );
}

1;

