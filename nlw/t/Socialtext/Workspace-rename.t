#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 12;
use Socialtext::EmailAlias;
use Socialtext::File;
use Socialtext::Paths;
use Socialtext::Account;
use Socialtext::Workspace;

# Fixtures: clean, help
#
# Need a clean environment to test against, so that we know that the workspace
# we're renaming to isn't here yet.
fixtures( 'clean', 'help' );

{
    my $ws = Socialtext::Workspace->create(
        name       => 'short-name',
        title      => 'Longer Title',
        account_id => Socialtext::Account->Socialtext()->account_id,
    );

    $ws->rename( name => 'new-name' );

    is( $ws->name(), 'new-name', 'workspace name is new-name' );

    for my $dir (
        Socialtext::Paths::page_data_directory('short-name'),
        Socialtext::Paths::plugin_directory('short-name'),
        Socialtext::Paths::user_directory('short-name'),
    ) {
        ok( ! -d $dir, "$dir does not exist after workspace is renamed" );
    }

    my $page_dir =
        Socialtext::File::catdir( Socialtext::Paths::page_data_directory('short-name'), 'quick_start' );
    ok( ! -d $page_dir, "$page_dir does not exist after workspace is renamed" );
    ok( ! Socialtext::EmailAlias::find_alias('short-name'),
        'short-name alias does not exist after rename' );

    for my $dir (
        Socialtext::Paths::page_data_directory('new-name'),
        Socialtext::Paths::plugin_directory('new-name'),
        Socialtext::Paths::user_directory('new-name'),
    ) {
        ok( -d $dir, "$dir exists after workspace is renamed" );
    }

    $page_dir =
        Socialtext::File::catdir( Socialtext::Paths::page_data_directory('new-name'), 'quick_start' );
    ok( -d $page_dir, "$page_dir exists after workspace is renamed" );

    my $index = Socialtext::File::catfile( $page_dir, 'index.txt' );
    ok( -f readlink $index, 'index.txt symlink points to real file' );

    ok( Socialtext::EmailAlias::find_alias('new-name'),
        'new-name alias exists after rename' );
}
