#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use File::Path qw(rmtree);
use File::Copy qw(move);
use Test::Socialtext tests => 15;
use Test::Exception;
use Socialtext;
use Socialtext::Hub;
use Socialtext::Account;
use Socialtext::Workspace;
use Socialtext::User;
use Socialtext::Page::TablePopulator;

fixtures( 'admin' );

my $SystemUser    = Socialtext::User->SystemUser();
my $SystemAccount = Socialtext::Account->Socialtext();

###############################################################################
# TEST: repopulate the Page table for a Workspace from scratch, recreating it
# completely.  We should be able to verify that we've recreated it properly if
# we remove one of the pages on-disk prior to repopulation; we'll have one
# less page in the DB when we're done.
populate_recreating_from_scratch: {
    # Create a dummy workspace to work with, filled with the default set of
    # pages.
    my $ws = Socialtext::Workspace->create(
        title      => 'Recreate from scratch',
        name       => 'recreate-from-scratch',
        account_id => $SystemAccount->account_id,
    );

    my $st  = Socialtext->new();
    my $hub = $st->load_hub(
        current_workspace => $ws,
        current_user      => $SystemUser,
    );
    $hub->registry->load();

    # Count up the number of pages in the Workspace; when we remove one of
    # them we'll want to make sure that it gets removed from the DB.
    my $all_pages = Socialtext::Model::Pages->All_active(
        hub          => $hub,
        workspace_id => $ws->workspace_id,
    );
    my $count_before_recreate = scalar @{$all_pages};

    # Purge one of the pages on-disk, so that when we re-feed the WS from the
    # on-disk representation it'll be missing.
    my $purged_page = $all_pages->[0];
    isa_ok $purged_page, 'Socialtext::Model::Page';

    my $page_path = $purged_page->directory_path();
    ok -d $page_path, 'page exists on disk';
    rmtree([$page_path]);
    ok !-d $page_path, '... and has now been removed from disk';

    # Repopulate the Page table, forcing it to be recreated from scratch
    my $populator = Socialtext::Page::TablePopulator->new(
        workspace_name => $ws->name,
    );
    lives_ok sub { $populator->populate(recreate => 1) },
        're-populated Page table';

    # Re-query the pages in the Workspace; we should have one less page than
    # we did before (as we purged one from disk).
    $all_pages = Socialtext::Model::Pages->All_active(
        hub          => $hub,
        workspace_id => $ws->workspace_id,
    );
    my $count_after_recreate = scalar @{$all_pages};
    is $count_after_recreate, $count_before_recreate - 1,
        'have one less pages in the Workspace';

    # Verify that the page that we purged DOESN'T exist in the list of Pages
    # in the WS any more (it shouldn't; we removed it).
    my @found = grep { $_->id eq $purged_page->id } @{$all_pages};
    ok !@found, '... the purged page is no longer present';
}

###############################################################################
# TEST: repopulate the Page table for a Workspace, only filling in the missing
# bits in the DB.  If we have dangling DB entries with no pages on disk they
# should be left alone, and other pages that are on disk but not in the DB
# should be filled in.
#
# We'll implement this by renaming one of the pages on disk behind the scenes,
# and then repopulating the DB.
populate_only_fill_in_missing_pages: {
    # Create a dummy workspace to work with, filled with the default set of
    # pages.
    my $ws = Socialtext::Workspace->create(
        title      => 'Repopulate missing pages',
        name       => 'repopulate-missing-pages',
        account_id => $SystemAccount->account_id,
    );

    my $st  = Socialtext->new();
    my $hub = $st->load_hub(
        current_workspace => $ws,
        current_user      => $SystemUser,
    );
    $hub->registry->load();

    # Count up the number of pages in the Workspace; when we're done we should
    # have one new page.
    my $all_pages = Socialtext::Model::Pages->All_active(
        hub          => $hub,
        workspace_id => $ws->workspace_id,
    );
    my $count_before_repopulate = scalar @{$all_pages};

    # Rename one of the pages on-disk behind the scenes.  This should give us
    # the effect of "one page in DB that isn't on disk any more *AND* a new
    # page on disk that isn't in the DB".
    my $renamed_page = $all_pages->[0];
    isa_ok $renamed_page, 'Socialtext::Model::Page';

    my $page_path = $renamed_page->directory_path();
    ok -d $page_path, 'page exists on disk';

    my $new_page_path = $page_path;
    $new_page_path =~ s{/[^/]+$}{/brand_new_page};
    ok move($page_path, $new_page_path), '... renamed on disk';
    ok !-d $page_path, '... and has now been removed from disk';
    ok -d $new_page_path, '... by pretending to make a new page out of it';

    # Repopulate the Page table, *WITHOUT* recreating everything from scratch
    my $populator = Socialtext::Page::TablePopulator->new(
        workspace_name => $ws->name,
    );
    lives_ok sub { $populator->populate() }, 're-populated Page table';

    # Re-query the pages in the Workspace; we should have one more page than
    # we did before (as we pretended to create a new page on disk).
    $all_pages = Socialtext::Model::Pages->All_active(
        hub          => $hub,
        workspace_id => $ws->workspace_id,
    );
    my $count_after_repopulate = scalar @{$all_pages};
    is $count_after_repopulate, $count_before_repopulate + 1,
        'have one more pages in the Workspace';

    # Verify that the the page we renamed still exists (as a dangling page in
    # the DB, even though it has no on-disk storage any more).
    my @found = grep { $_->id eq $renamed_page->id } @{$all_pages};
    ok @found, '... the dangling page in the DB is still in the DB';

    # Verify that the new page we created (by renaming the other page) exists
    @found = grep { $_->id eq 'brand_new_page' } @{$all_pages};
    ok @found, '... the dangling page on disk was added to the DB';
}
