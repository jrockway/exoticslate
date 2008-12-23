# @COPYRIGHT@
package Socialtext::TechnoratiPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use Class::Field qw( const );

# XXX this class should stop using Socialtext::FetchRSSPlugin for 
# retrieval and should instead use WebService::Technorati.
# In its current form it is unable to use the technorati api
# to full effect.

sub class_id { 'technorati' }
const class_title          => 'Technorati';
const default_cache_expire => '1 h';
const default_technorati_timeout => 60;
const technorati_base_url  => 'http://api.technorati.com/cosmos';

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(prequisite => 'fetchrss');
    $registry->add(wafl => technorati => 'Socialtext::TechnoratiPhrase::Wafl');
}

sub get_technorati_cosmos {
    my $self = shift;
    my $url = shift;

    my $search_url = $self->uri_escape($url);
    $self->hub->fetchrss->timeout($self->default_technorati_timeout);

    my $cosmos = $self->hub->fetchrss->get_feed(
        $self->_techno_url($search_url), $self->default_cache_expire);

    return $cosmos if $cosmos;

    if ($self->hub->fetchrss->error) {
        warn "Error fetching Tecnorati feed: " . $self->hub->fetchrss->error;
        $self->hub->fetchrss->error(
            'Bad technorati key or invalid response from technorati'
        );
    }
    return;
}
    
sub key {
    my $self = shift;
    Socialtext::AppConfig->technorati_key;
}

sub _techno_url {
    my $self = shift;
    my $url = shift;
    my $technorati_key = $self->hub->technorati->key;
    return $self->technorati_base_url .
        "?key=$technorati_key&url=$url&" .
        'type=link&format=rss&limit=10';
}

##########################################################################
package Socialtext::TechnoratiPhrase::Wafl;

use Socialtext::Formatter::WaflPhrase;
use base 'Socialtext::Formatter::WaflPhraseDiv';

sub html {
    my $self = shift;
    my $url = $self->arguments;
    my $feed = $self->hub->technorati->get_technorati_cosmos($url);
    return $self->hub->template->process('fetchrss.html',
            full => 1,
            method => $self->method,
            fetchrss_url => $url,
            feed => $feed,
            fetchrss_error => $self->hub->fetchrss->error,
    );
}

1;

