#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More qw/no_plan/;
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
        ),
    );
    my $hp = Socialtext::HomepagePlugin->new( hub => $mock_hub );
    like $hp->homepage, qr/Dashboard/;
}

Weblog: {
    my $mock_hub = Socialtext::Hub->new(
        current_workspace => Socialtext::Workspace->new(
            homepage_weblog => 'monkey',
        ),
    );
    my $hp = Socialtext::HomepagePlugin->new( hub => $mock_hub );
    is $hp->homepage, '';
    is $Socialtext::Headers::REDIRECT, '?action=weblog_display;category=monkey';
}
