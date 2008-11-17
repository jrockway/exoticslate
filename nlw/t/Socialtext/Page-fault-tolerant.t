#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;

use File::Spec;
use Socialtext::Account;
use Socialtext::AppConfig;
use Socialtext::Page;
use Socialtext::File;
use Socialtext::Workspace;
use Test::Socialtext tests => 4;
fixtures( 'clean', 'admin' );

BEGIN {
    use_ok( 'Socialtext::Page' );
}
my $acc = Socialtext::Account->Socialtext;
my $ws_name = 'tolerance';
my $ws = Socialtext::Workspace->create(
    name       => $ws_name,
    title      => 'Fault Tolerant Workspace',
    account_id => $acc->account_id,
    empty      => 1
);

my $hub = new_hub( $ws_name );
my $data_path = Socialtext::Paths::page_data_directory( $ws->name );

Dir_exists_with_no_files: {
    my $page_name = 'no_files';
    my $dir = File::Spec->catfile( $data_path, $page_name );

    mkdir $dir;

    my $page = Socialtext::Page->new(
        hub  => $hub,
        id   => $page_name,
    );

    is( '', $page->assert_revision_id, 'page has no revisions' );
}

Page_has_no_index_symlink: {
    my $page_name = 'no_index_file';
    my $page = Socialtext::Page->new( hub => $hub )->create(
        title   => $page_name,
        content => 'Some Content',
        creator => $hub->current_user
    );

    my $dir = File::Spec->catfile( $data_path, $page_name );
    unlink "$dir/index.txt";
    my $revision = qx/ls $dir | cut -d '.' -f 1/;
    chomp( $revision );

    is($revision, $page->assert_revision_id,
        'revision found with index file missing.');
}

Page_with_no_index_and_multiple_revisions: {
    my $page_name = 'multiple_revisions';
    my $page = Socialtext::Page->new( hub => $hub )->create(
        title => $page_name,
        content => 'First Revision',
        creator => $hub->current_user
    );

    $page->append( 'More Data' );
    sleep( 2 ); # so we don't kill the first revision.
    $page->store( user => $hub->current_user );

    my $dir = File::Spec->catfile( $data_path, $page_name );
    unlink "$dir/index.txt";

    my $revision = qx/ls -t1 $dir | head -n 1 | cut -d '.' -f 1/;
    chomp( $revision );
    is($revision, $page->assert_revision_id,
        'correct revision found with missing index file.');
}
