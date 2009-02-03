#!perl
# @COPYRIGHT@

use strict;
use warnings;

use mocked 'Apache';
use mocked 'Apache::Cookie';
use Test::Socialtext tests => 29;
fixtures( 'admin' );

BEGIN {
    use_ok( 'Socialtext::EditPlugin' );
}

my @revision_ids;
my $save_revision_id;

my $hub = new_hub('admin');
my $page;
$page = Socialtext::Page->new( hub => $hub )->create(
    title   => 'revision_page',
    content => 'First Paragraph',
    creator => $hub->current_user,
);
@revision_ids = $page->all_revision_ids();

$page = Socialtext::Page->new( hub => $hub )->create(
    title   => 'save_page',
    content => 'First Paragraph',
    creator => $hub->current_user,
);
$save_revision_id = $page->revision_id;

EDIT_CONTENT: {
    my $hub = new_hub('admin');
    my $cgi = $hub->rest->query;
    $cgi->param('page_name', 'revision_page');
    $cgi->param('revision_id', $revision_ids[0]);
    $cgi->param('page_body', 'Hello');
    $cgi->param('action', 'edit_content');
    $cgi->param('caller_action', '');
    $cgi->param('append_mode', '');
    $cgi->param('page_body_decoy', 'Hello');


    my $return = $hub->edit->edit_content;
    is($return, '', 'Nothing returned because OK edit_content redirects');

    my $page = Socialtext::Page->new(hub => $hub, id => 'revision_page')->load();
    my @ids = $page->all_revision_ids();
    @revision_ids = @ids;
    is(scalar(@ids), 2, '2 Revisions');
    is($page->content, "Hello\n", 'New content saved');
}

EDIT: {
    my $hub = new_hub('admin');
    my $cgi = $hub->rest->query;
    $cgi->param('page_name', 'revision_page');
    $cgi->param('revision_id', $revision_ids[-1]);
    $cgi->param('page_body', 'Hello');
    $cgi->param('action', 'edit');
    $cgi->param('caller_action', '');
    $cgi->param('append_mode', '');
    $cgi->param('page_body_decoy', 'Hello');

    my $return = $hub->edit->edit;
    ok($return =~ /Socialtext.start_in_edit_mode\s*=\s*true;/, 'Page returned with edit mode triggered');
}

EDIT_CONTENT_contention: {
    my $hub = new_hub('admin');
    my $cgi = $hub->rest->query;
    $cgi->param('page_name', 'revision_page');
    $cgi->param('revision_id', $revision_ids[0]);
    $cgi->param('page_body', 'Should Be A Contention');
    $cgi->param('action', 'edit_content');
    $cgi->param('caller_action', '');
    $cgi->param('append_mode', '');
    $cgi->param('page_body_decoy', 'Hello');

    my $return = $hub->edit->edit_content;
    ok($return =~ /st-editcontention/, 'Edit contention dialog displayed');

    my $page = Socialtext::Page->new(hub => $hub, id => 'revision_page')->load();
    my @ids = $page->all_revision_ids();
    is(scalar(@ids), 2, "2 Revisions @ids");
    is($page->content, "Hello\n", 'New content not saved');
}

EDIT_CONTENT_contention_other_than_content: {
    my $hub = new_hub('admin');
    my $cgi = $hub->rest->query;
    $cgi->param('page_name', 'revision_page');
    $cgi->param('revision_id', $revision_ids[0]);
    $cgi->param('page_body', 'Should Be No Contention');
    $cgi->param('action', 'edit_content');
    $cgi->param('caller_action', '');
    $cgi->param('append_mode', '');
    $cgi->param('page_body_decoy', 'Hello');

    my $page = Socialtext::Page->new(hub => $hub, id => 'revision_page')->load_revision($revision_ids[0]);
    my $content = $page->content;
    $page = Socialtext::Page->new(hub => $hub, id => 'revision_page')->load;
    $page->content($content);
    $page->store(user => $hub->current_user);

    my $return = $hub->edit->edit_content;
    is($return, '', 'Nothing returned because OK save redirects');

    $page = Socialtext::Page->new(hub => $hub, id => 'revision_page')->load();
    is($page->revision_count, 4, '4 Revisions');
    is($page->content, "Should Be No Contention\n", 'New content saved');
}

_EDIT_CONTENTION_SCREEN: {
    my $hub = new_hub('admin');
    my $cgi = $hub->rest->query;
    $cgi->param('page_name', 'revision_page');
    $cgi->param('revision_id', $revision_ids[0]);
    $cgi->param('page_body', 'This is an edit contention');
    $cgi->param('action', 'edit_content');
    $cgi->param('caller_action', '');
    $cgi->param('append_mode', '');
    $cgi->param('page_body_decoy', 'Hello');
    my $page = Socialtext::Page->new(hub => $hub, id => 'revision_page')->load;

    my $return = $hub->edit->_edit_contention_screen($page);
    like($return, qr/Somebody else made changes to the document/, 'HTML contains contention message');
    ok($return =~ /This is an edit contention/, 'HTML contains new content');
}

_THERE_IS_AN_EDIT_CONTENTION_revision_ids_the_same: {
    my $hub = new_hub('admin');
    my $page = Socialtext::Page->new(hub => $hub, id => 'revision_page')->load;
    my $return = $hub->edit->_there_is_an_edit_contention($page, $page->revision_id);
    is($return, 0, 'No edit contention');
}

_THERE_IS_AN_EDIT_CONTENTION_different_revision_ids_different_content: {
    my $hub = new_hub('admin');
    my $page = Socialtext::Page->new(hub => $hub, id => 'revision_page')->load;
    $page->content('Different Content');

    my $return = $hub->edit->_there_is_an_edit_contention($page, $revision_ids[0]);
    is($return, 1, 'There is edit contention');
}

_THERE_IS_AN_EDIT_CONTENTION_different_revision_ids_same_content: {
    my $hub = new_hub('admin');
    my $page = Socialtext::Page->new(hub => $hub, id => 'revision_page')->load;
    $page->content('Same Content');
    $page->store(user => $hub->current_user);
    my $previous_revision = $page->revision_id;
    $page->store(user => $hub->current_user);

    my $return = $hub->edit->_there_is_an_edit_contention($page, $previous_revision);
    ok !$return, 'No edit contention';
}

SAVE: {
    my $hub = new_hub('admin');
    my $cgi = $hub->rest->query;
    $cgi->param('page_name', 'save_page');
    $cgi->param('revision_id', $save_revision_id);
    $cgi->param('page_body', 'Hello');
    $cgi->param('action', 'edit_save');
    $cgi->param('caller_action', '');
    $cgi->param('append_mode', '');
    $cgi->param('page_body_decoy', 'Hello');
    $cgi->param('original_page_id', 'save_page');
    $cgi->param('subject', 'save_page');
    $cgi->param('add_tag', "one\n");

    my $return = $hub->edit->save;
    is($return, '', 'Nothing returned because OK save redirects');

    my $page = Socialtext::Page->new(hub => $hub, id => 'save_page')->load();
    is($page->metadata->Category->[0], 'one', "chomped new line on addinga  tag");
    is($page->revision_count, 2, '2 Revisions');
    is($page->content, "Hello\n", 'New content saved');
}

SAVE_contention: {
    my $hub = new_hub('admin');
    my $cgi = $hub->rest->query;
    $cgi->param('page_name', 'save_page');
    $cgi->param('revision_id', $save_revision_id);
    $cgi->param('page_body', 'Should Be A Contention');
    $cgi->param('action', 'edit_save');
    $cgi->param('caller_action', '');
    $cgi->param('append_mode', '');
    $cgi->param('page_body_decoy', 'Hello');
    $cgi->param('original_page_id', 'save_page');
    $cgi->param('subject', 'save_page');

    my $return = $hub->edit->edit_content;
    ok($return =~ /st-editcontention/, 'Edit contention dialog displayed');

    my $page = Socialtext::Page->new(hub => $hub, id => 'save_page')->load();
    is($page->revision_count, 2, '2 Revisions');
    is($page->content, "Hello\n", 'New content not saved');
    $save_revision_id = $page->revision_id;
}

EDIT_SUMMARY: {
    my $hub = new_hub('admin');
    my $cgi = $hub->rest->query;
    $cgi->param('page_name', 'save_page');
    $cgi->param('revision_id', $save_revision_id);
    $cgi->param('page_body', 'testing summaries');
    $cgi->param('action', 'edit_save');
    $cgi->param('caller_action', '');
    $cgi->param('append_mode', '');
    $cgi->param('page_body_decoy', 'Hello');
    $cgi->param('edit_summary', ' i suck at typing  ');

    my $return = $hub->edit->edit_content;
    my $page = Socialtext::Page->new(hub => $hub, id => 'save_page')->load();
    is($page->content, "testing summaries\n");

    is($page->metadata->RevisionSummary, 'i suck at typing', "edit summary was saved");
    is($page->edit_summary, 'i suck at typing', 'proxy method works');
    $save_revision_id = $page->revision_id;
}

EDIT_SUMMARY_VIA_SAVE: {
    my $hub = new_hub('admin');
    my $cgi = $hub->rest->query;
    $cgi->param('page_name', 'save_page');
    $cgi->param('revision_id', $save_revision_id);
    $cgi->param('page_body', 'testing summaries via save');
    $cgi->param('action', 'edit_save');
    $cgi->param('caller_action', '');
    $cgi->param('append_mode', '');
    $cgi->param('page_body_decoy', 'Hello');
    $cgi->param('original_page_id', 'save_page');
    $cgi->param('subject', 'save_page');
    $cgi->param('edit_summary', '   i really suck at typing   ');

    my $return = $hub->edit->save;
    my $page = Socialtext::Page->new(hub => $hub, id => 'save_page')->load();
    is($page->content, "testing summaries via save\n");

    is($page->metadata->RevisionSummary, 'i really suck at typing', "edit summary was saved");
    is($page->edit_summary, 'i really suck at typing', 'proxy method works');
}
