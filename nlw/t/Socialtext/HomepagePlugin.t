#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More tests => 6;
use mocked 'Apache::Cookie';
use mocked 'Socialtext::Search::Set';
use mocked 'Socialtext::Search::Config';
use mocked 'Socialtext::Hub';

BEGIN {
    use_ok 'Socialtext::HomepagePlugin';
}


Central_page: {
    my $mock_hub = Socialtext::Hub->new;
    my $hp = Socialtext::HomepagePlugin->new( hub => $mock_hub );
    is $hp->homepage, '';
    is $Socialtext::Headers::REDIRECT, 'full_uri?current';
}

Dashboard: {
    my $mock_hub = Socialtext::Hub->new(
        current_workspace => Socialtext::Workspace->new(
            homepage_is_dashboard => 1,
            workspace_id => 1,
        ),
    );
    my $hp = Socialtext::HomepagePlugin->new( hub => $mock_hub );
    {
        no strict 'refs'; no warnings 'redefine', 'once';
        like $hp->homepage, qr/Dashboard/;
    }
}

Weblog: {
    my $mock_hub = Socialtext::Hub->new(
        current_workspace => Socialtext::Workspace->new(
            homepage_weblog => 'monkey',
            workspace_id => 1,
        ),
    );
    my $hp = Socialtext::HomepagePlugin->new( hub => $mock_hub );
    is $hp->homepage, '';
    is $Socialtext::Headers::REDIRECT, '?action=weblog_display;category=monkey';
}
