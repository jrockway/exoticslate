#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;

use Socialtext;
use Socialtext::Account;
use Socialtext::Paths;
use Socialtext::User;
use Socialtext::Workspace;
use Test::Socialtext tests => 7;
use Test::Warn;

fixtures( 'clean', 'admin');

BEGIN {
  use_ok( 'Socialtext::Page::TablePopulator' );
}

my $ws = Socialtext::Workspace->create(
    name       => 'to-pop',
    title      => 'To Pop',
    account_id => Socialtext::Account->Socialtext->account_id
);

my $st = Socialtext->new();
my $hub = $st->load_hub(
    current_workspace => $ws,
    current_user      => Socialtext::User->SystemUser,
);
$hub->registry->load;

my $data_path = Socialtext::Paths::page_data_directory( $ws->name );

for my $i (1..6) {
    my $page = Socialtext::Page->new( hub => $hub )->create(
        title => "Page $i",
        content => "Page $i -- Content.",
        creator => $hub->current_user,
    );

    next unless $i == 5 or $i == 6;

    sleep( 2 );
    $page->append( "More for $i ..." );
    $page->store( user => $hub->current_user );
}

Populator_find_current_revision: {

    # no revisions, no index file.
    my $dir = File::Spec->catfile( $data_path, 'page_1' );
    system( "rm $dir/*" );
    eval { Socialtext::Page::TablePopulator::find_current_revision( $dir ) };
    like( $@, qr/^Couldn't find revision page for / );

    # one revision, no index file.
    $dir = File::Spec->catfile( $data_path, 'page_3' );
    unlink( "$dir/index.txt" );
    my $result = 
        Socialtext::Page::TablePopulator::find_current_revision( $dir );
    my $expected = qx/ls -1 $dir /;
    chomp( $expected );
    is( $result, $expected );

    # Multiple revisions, no index file.
    $dir = File::Spec->catfile( $data_path, 'page_5' );
    unlink( "$dir/index.txt" );
    $result =
        Socialtext::Page::TablePopulator::find_current_revision( $dir );
    $expected = qx/ls $dir -t1 | head -n 1/;
    chomp( $expected );
    is( $result, $expected );

    # Testing with an existing index file.
    $dir = File::Spec->catfile( $data_path, 'page_6' );
    $result =
        Socialtext::Page::TablePopulator::find_current_revision( $dir );
    $result =~ s/^.+\///;
    $expected = qx/ls $dir -t1 | head -n 1/;
    chomp( $expected );
    is( $result, $expected );
}

Populator_fix_relative_page_link: {
    my $dir = File::Spec->catfile( $data_path, 'page_4' );
    unlink( "$dir/index.txt" );
    warning_like {
        Socialtext::Page::TablePopulator::fix_relative_page_link( $dir )
    } [qr/Fixed relative symlink in $dir/];
    ok( -f "$dir/index.txt" );
}
