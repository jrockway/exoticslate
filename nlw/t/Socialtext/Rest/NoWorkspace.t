#!/usr/bin/perl
use strict;
use warnings;
use Test::More qw/no_plan/;
use mocked 'Socialtext::Rest';
use mocked 'Socialtext::Session';
use mocked 'Socialtext::Workspace';
use mocked 'Socialtext::AppConfig';
use mocked 'Socialtext::Challenger';
use mocked 'Socialtext::Permission';
use Socialtext::SQL;
$Socialtext::SQL::DEBUG = 1;

BEGIN {
    use_ok 'Socialtext::Rest::NoWorkspace';
}

Last_workspace_from_session: {
    local $Socialtext::Session::LAST_WORKSPACE_ID = 1;
    my $handler = Socialtext::Rest::NoWorkspace->new;

    my $rest = Socialtext::Rest->new;
    is $handler->handler($rest), '';
    like $rest->{headers}{-Location}, qr#/workspace_1/#;
    is $rest->{headers}{-status}, '302 Found';
}

User_workspace: {
    my $handler = Socialtext::Rest::NoWorkspace->new;

    local $Socialtext::User::WORKSPACES = [ [ 2 ] ];
    my $rest = Socialtext::Rest->new;
    is $handler->handler($rest), '';
    like $rest->{headers}{-Location}, qr#/workspace_2/#;
    is $rest->{headers}{-status}, '302 Found';
}

Default_workspace: {
    my $handler = Socialtext::Rest::NoWorkspace->new;

    local $Socialtext::User::WORKSPACES = [ ];
    my $rest = Socialtext::Rest->new;
    is $handler->handler($rest), '';
    like $rest->{headers}{-Location}, qr#/workspace_default/#;
    is $rest->{headers}{-status}, '302 Found';
}

Fall_through_to_help: {
    my $handler = Socialtext::Rest::NoWorkspace->new;

    local $Socialtext::User::WORKSPACES = [ ];
    local $Socialtext::AppConfig::DEFAULT_WORKSPACE = undef;
    my $rest = Socialtext::Rest->new;
    is $handler->handler($rest), '';
    like $rest->{headers}{-Location}, qr#/workspace_help/#;
    is $rest->{headers}{-status}, '302 Found';
}

