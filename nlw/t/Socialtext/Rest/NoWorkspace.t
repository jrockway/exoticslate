#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More qw/no_plan/;
use mocked 'Socialtext::Authz';
use mocked 'Socialtext::Permission';
use mocked 'Socialtext::AppConfig';
use mocked 'Socialtext::l10n';
use mocked 'Socialtext::Workspace';
use mocked 'Socialtext::Session';
use mocked 'Socialtext::Rest';
use mocked 'Socialtext::Challenger';
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
    like $rest->{header}{-Location}, qr#/workspace_1/#;
    is $rest->{header}{-status}, '302 Found';
}

Read_breadcrumbs: {
    my $handler = Socialtext::Rest::NoWorkspace->new;

    local @Socialtext::Workspace::BREADCRUMBS = (
        Socialtext::Workspace->new( name => 'foo' ),
        Socialtext::Workspace->new( name => 'bar' ),
    );
    my $rest = Socialtext::Rest->new;
    is $handler->handler($rest), '';
    like $rest->{header}{-Location}, qr#/workspace_foo/#;
    is $rest->{header}{-status}, '302 Found';
}

Default_workspace: {
    my $handler = Socialtext::Rest::NoWorkspace->new;

    local $Socialtext::User::WORKSPACES = [ ];
    my $rest = Socialtext::Rest->new;
    is $handler->handler($rest), '';
    like $rest->{header}{-Location}, qr#/workspace_default/#;
    is $rest->{header}{-status}, '302 Found';
}

Fall_through_to_help: {
    my $handler = Socialtext::Rest::NoWorkspace->new;

    local $Socialtext::User::WORKSPACES = [ ];
    local $Socialtext::AppConfig::DEFAULT_WORKSPACE = undef;
    my $rest = Socialtext::Rest->new;
    is $handler->handler($rest), '';
    like $rest->{header}{-Location}, qr#/workspace_help/#;
    is $rest->{header}{-status}, '302 Found';
}

