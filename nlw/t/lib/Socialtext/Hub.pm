package Socialtext::Hub;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::MockBase';
use mocked 'Socialtext::Workspace';
use mocked 'Socialtext::Pages';
use mocked 'Socialtext::CGI';
use mocked 'Socialtext::Headers';
use mocked 'Socialtext::Preferences';
use mocked 'Socialtext::User';
use mocked 'Socialtext::Watchlist';
use unmocked 'Socialtext::Helpers';
use unmocked 'Socialtext::DisplayPlugin';
use unmocked 'Socialtext::FavoritesPlugin';
use unmocked 'Socialtext::CategoryPlugin';
use unmocked 'Socialtext::RecentChangesPlugin';
use unmocked 'Socialtext::SyndicatePlugin';
use unmocked 'Socialtext::TiddlyPlugin';
use unmocked 'Socialtext::CSS';

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

sub current_user { $_[0]->{current_user} || Socialtext::User->new }

sub checker { shift }

sub best_locale { 'en' }

# for "simplicity" main just returns ourself
sub main { shift }
sub status_message { 'mock_hub_status_message' }


# These methods return real libraries
sub helpers { $_[0]->{helpers} || Socialtext::Helpers->new(hub => $_[0]) }
sub display { $_[0]->{display} || Socialtext::DisplayPlugin->new(hub => $_[0]) }
sub css { $_[0]->{css} || Socialtext::CSS->new(hub => $_[0]) }
sub favorites { $_[0]->{favorites} || Socialtext::FavoritesPlugin->new(hub => $_[0]) }
sub category { $_[0]->{category} || Socialtext::CategoryPlugin->new(hub => $_[0]) }
sub recent_changes { $_[0]->{recent_changes} || Socialtext::RecentChangesPlugin->new(hub => $_[0]) }
sub syndicate { $_[0]->{syndicate} || Socialtext::SyndicatePlugin->new(hub => $_[0]) }
sub tiddly { $_[0]->{tiddly} || Socialtext::TiddlyPlugin->new(hub => $_[0]) }

1;
