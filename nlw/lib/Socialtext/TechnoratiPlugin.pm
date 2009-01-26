# @COPYRIGHT@
package Socialtext::TechnoratiPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use XML::Simple ();
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

sub _transform_tapi_to_rss20 {
    my $self = shift;
    my $content = shift or return;

    my $in = XML::Simple::XMLin($content);
    my $result_url = $in->{document}{result}{url}
        or die "$in->{document}{result}{error}\n";

    my @items;
    foreach my $item (@{ $in->{document}{item} || []}) {
        push @items, {
            title       => $item->{title} || ($item->{weblog} or next)->{name},
            link        => $item->{nearestpermalink} || ($item->{weblog} or next)->{url},
            description => $item->{excerpt},
        };
    }

    my $out = {
        title   => "Blog reactions to $result_url",
        item    => \@items,
    };

    my $rss = XML::Simple::XMLout($out, NoAttr => 1, RootName => 'channel');

    return << ".";
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
$rss
</rss>
.
}

sub get_technorati_cosmos {
    my $self = shift;
    my $url = shift;

    my $search_url = $self->uri_escape($url);
    $self->hub->fetchrss->timeout($self->default_technorati_timeout);

    my $fetchrss = $self->hub->fetchrss;
    my $techno_url = $self->_techno_url($search_url);
    my $feed = $fetchrss->_fetch_feed(
        $techno_url, $self->default_cache_expire
    );
    my $cosmos = eval { $fetchrss->_parse_feed(
        $techno_url, $self->_transform_tapi_to_rss20($feed)
    ) };
    return $cosmos if $cosmos;

    my $error = ($@ || $self->hub->fetchrss->error);
    if ($error) {
        warn "Error fetching Technorati feed: " . $error;
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
        'type=link&limit=10';
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

