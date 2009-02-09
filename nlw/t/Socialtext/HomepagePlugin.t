#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More tests => 8;
use mocked 'Apache::Cookie';
use mocked 'Socialtext::Search::Config';
use mocked 'Socialtext::User';
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

S2_Homepage: {
    my $mock_hub = Socialtext::Hub->new(
        current_workspace => Socialtext::Workspace->new(
            homepage_is_dashboard => 1,
            workspace_id => 1,
            skin_name => 's2',
        ),
    );
    my $hp = Socialtext::HomepagePlugin->new( hub => $mock_hub );
    {
        no strict 'refs'; no warnings 'redefine', 'once';
        like $hp->homepage, qr/Dashboard/;
    }
}


S2_Wikis_info: {
    my $wksp = Socialtext::Workspace->new(
        homepage_is_dashboard => 0,
        workspace_id => 1,
        skin_name => 's2',
    );
    local @Socialtext::Workspace::BREADCRUMBS = ($wksp);
    my $mock_hub = Socialtext::Hub->new(
        current_workspace => $wksp,
    );
    my $hp = Socialtext::HomepagePlugin->new( hub => $mock_hub );
    {
        no strict 'refs'; no warnings 'redefine', 'once';
        my $info = $hp->_get_wikis_info;
        is scalar(@$info), 1;
    }
}

S3_Dashboard: {
    my $mock_hub = Socialtext::Hub->new(
        current_workspace => Socialtext::Workspace->new(
            homepage_is_dashboard => 1,
            workspace_id => 1,
        ),
    );
    my $hp = Socialtext::HomepagePlugin->new( hub => $mock_hub );
    {
        no strict 'refs'; no warnings 'redefine', 'once';
        is $hp->homepage, ''; # redirect
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
