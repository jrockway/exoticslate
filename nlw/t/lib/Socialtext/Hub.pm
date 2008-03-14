package Socialtext::Hub;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::MockBase';
# Because we're mocked, we load other mocked libraries.
use Socialtext::Workspace;
use Socialtext::Pages;
use Socialtext::CGI;
use Socialtext::Headers;
use Socialtext::Preferences;
use Socialtext::User;
use Socialtext::Watchlist;
use unmocked 'Socialtext::Helpers';
use unmocked 'Socialtext::DisplayPlugin';
use unmocked 'Socialtext::FavoritesPlugin';
use unmocked 'Socialtext::CategoryPlugin';
use unmocked 'Socialtext::RecentChangesPlugin';
use unmocked 'Socialtext::SyndicatePlugin';
use unmocked 'Socialtext::TiddlyPlugin';
use unmocked 'Socialtext::CSS';
use unmocked 'Socialtext::FetchRSSPlugin';
use unmocked 'Socialtext::Template';
use unmocked 'Socialtext::Stax';

sub current_workspace {
    my $self = shift;
    $self->{current_workspace} ||= Socialtext::Workspace->new(
        title => 'current'
    );
    return $self->{current_workspace};
}

sub pages {
    my $self = shift;
    $self->{pages} ||= Socialtext::Pages->new;
    return $self->{pages};
}

sub headers { $_[0]->{headers} || Socialtext::Headers->new };

sub cgi { $_[0]->{cgi} || Socialtext::CGI->new }

sub preferences_object { $_[0]->{preferences} || Socialtext::Preferences->new }
sub preferences        { $_[0]->preferences_object }

sub current_user { $_[0]->{current_user} || Socialtext::User->new }

sub checker { shift }

sub best_locale { 'en' }

# for "simplicity" main just returns ourself
sub main { shift }
sub status_message { 'mock_hub_status_message' }


# These methods return real libraries
sub helpers { 
    return $_[0]->{helpers} ||= Socialtext::Helpers->new(hub => $_[0]);
}
sub skin { $_[0]->{skin} || Socialtext::Skin->new(hub => $_[0]) }

sub display { 
    return $_[0]->{display} ||= Socialtext::DisplayPlugin->new(hub => $_[0]);
}

sub css { 
    return $_[0]->{css} ||= Socialtext::CSS->new(hub => $_[0]);
}

sub favorites { 
    return $_[0]->{favorites} ||= 
        Socialtext::FavoritesPlugin->new(hub => $_[0]);
}

sub category { 
    return $_[0]->{category} ||= Socialtext::CategoryPlugin->new(hub => $_[0]);
}

sub recent_changes { 
    return $_[0]->{recent_changes} ||= 
        Socialtext::RecentChangesPlugin->new(hub => $_[0]);
}

sub syndicate { 
    return $_[0]->{syndicate} ||= Socialtext::SyndicatePlugin->new(hub => $_[0]);
}

sub tiddly { 
    return $_[0]->{tiddly} ||= Socialtext::TiddlyPlugin->new(hub => $_[0]);
}

sub fetchrss { 
    return $_[0]->{fetchrss} ||= Socialtext::FetchRSSPlugin->new(hub => $_[0]);
}

sub template {
    return $_[0]->{template} ||= Socialtext::Template->new(hub => $_[0]);
}

sub stax {
    return $_[0]->{stax} ||= Socialtext::Stax->new(hub => $_[0]);
}

1;
