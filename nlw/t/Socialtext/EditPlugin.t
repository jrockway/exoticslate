#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 23;
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
    sleep(2);
    CGI::param('page_name', 'revision_page');
    CGI::param('revision_id', $revision_ids[0]);
    CGI::param('page_body', 'Hello');
    CGI::param('action', 'edit_content');
    CGI::param('caller_action', '');
    CGI::param('append_mode', '');
    CGI::param('page_body_decoy', 'Hello');

    my $hub = new_hub('admin');

    my $return = $hub->edit->edit_content;
    is($return, '', 'Nothing returned because OK edit_content redirects');

    my $page = Socialtext::Page->new(hub => $hub, id => 'revision_page')->load();
    my @ids = $page->all_revision_ids();
    @revision_ids = @ids;
    is(scalar(@ids), 2, '2 Revisions');
    is($page->content, "Hello\n", 'New content saved');
}

EDIT: {
    sleep(2);
    CGI::param('page_name', 'revision_page');
    CGI::param('revision_id', $revision_ids[-1]);
    CGI::param('page_body', 'Hello');
    CGI::param('action', 'edit');
    CGI::param('caller_action', '');
    CGI::param('append_mode', '');
    CGI::param('page_body_decoy', 'Hello');

    my $hub = new_hub('admin');

    my $return = $hub->edit->edit;
    ok($return =~ /Socialtext.start_in_edit_mode\s*=\s*true;/, 'Page returned with edit mode triggered');
}

EDIT_CONTENT_contention: {
    sleep(2);
    CGI::param('page_name', 'revision_page');
    CGI::param('revision_id', $revision_ids[0]);
    CGI::param('page_body', 'Should Be A Contention');
    CGI::param('action', 'edit_content');
    CGI::param('caller_action', '');
    CGI::param('append_mode', '');
    CGI::param('page_body_decoy', 'Hello');

    my $hub = new_hub('admin');

    my $return = $hub->edit->edit_content;
    ok($return =~ /st-editcontention/, 'Edit contention dialog displayed');

    my $page = Socialtext::Page->new(hub => $hub, id => 'revision_page')->load();
    my @ids = $page->all_revision_ids();
    is(scalar(@ids), 3, '3 Revisions');
    is($page->content, "Hello\n", 'New content not saved');
}

EDIT_CONTENT_contention_other_than_content: {
    sleep(2);

    CGI::param('page_name', 'revision_page');
    CGI::param('revision_id', $revision_ids[0]);
    CGI::param('page_body', 'Should Be No Contention');
    CGI::param('action', 'edit_content');
    CGI::param('caller_action', '');
    CGI::param('append_mode', '');
    CGI::param('page_body_decoy', 'Hello');

    my $hub = new_hub('admin');

    my $page = Socialtext::Page->new(hub => $hub, id => 'revision_page')->load_revision($revision_ids[0]);
    my $content = $page->content;
    $page = Socialtext::Page->new(hub => $hub, id => 'revision_page')->load;
    $page->content($content);
    $page->store(user => $hub->current_user);
    sleep(2);

    my $return = $hub->edit->edit_content;
    is($return, '', 'Nothing returned because OK save redirects');

    $page = Socialtext::Page->new(hub => $hub, id => 'revision_page')->load();
    my @ids = $page->all_revision_ids();
    is(scalar(@ids), 5, '5 Revisions');
    is($page->content, "Should Be No Contention\n", 'New content saved');
}

_EDIT_CONTENTION_SCREEN: {
    CGI::param('page_name', 'revision_page');
    CGI::param('revision_id', $revision_ids[0]);
    CGI::param('page_body', 'This is an edit contention');
    CGI::param('action', 'edit_content');
    CGI::param('caller_action', '');
    CGI::param('append_mode', '');
    CGI::param('page_body_decoy', 'Hello');

    my $hub = new_hub('admin');
    my $page = Socialtext::Page->new(hub => $hub, id => 'revision_page')->load;

    my $return = $hub->edit->_edit_contention_screen($page);
    ok($return =~ /Somebody else made changes to the page/, 'HTML contains contention message');
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
    sleep(2);
    $page->store(user => $hub->current_user);

    my $return = $hub->edit->_there_is_an_edit_contention($page, $previous_revision);
    is($return, 0, 'No edit contention');
}

SAVE: {
    sleep(2);
    CGI::param('page_name', 'save_page');
    CGI::param('revision_id', $save_revision_id);
    CGI::param('page_body', 'Hello');
    CGI::param('action', 'edit_save');
    CGI::param('caller_action', '');
    CGI::param('append_mode', '');
    CGI::param('page_body_decoy', 'Hello');
    CGI::param('original_page_id', 'save_page');
    CGI::param('subject', 'save_page');
    CGI::param('add_tag', "one\n");

    my $hub = new_hub('admin');

    my $return = $hub->edit->save;
    is($return, '', 'Nothing returned because OK save redirects');

    my $page = Socialtext::Page->new(hub => $hub, id => 'save_page')->load();
    my @ids = $page->all_revision_ids();
    is($page->metadata->Category->[0], 'one', "chomped new line on addinga  tag");
    is(scalar(@ids), 2, '2 Revisions');
    is($page->content, "Hello\n", 'New content saved');
}

SAVE_contention: {
    sleep(2);
    CGI::param('page_name', 'save_page');
    CGI::param('revision_id', $save_revision_id);
    CGI::param('page_body', 'Should Be A Contention');
    CGI::param('action', 'edit_save');
    CGI::param('caller_action', '');
    CGI::param('append_mode', '');
    CGI::param('page_body_decoy', 'Hello');
    CGI::param('original_page_id', 'save_page');
    CGI::param('subject', 'save_page');

    my $hub = new_hub('admin');

    my $return = $hub->edit->edit_content;
    ok($return =~ /st-editcontention/, 'Edit contention dialog displayed');

    my $page = Socialtext::Page->new(hub => $hub, id => 'save_page')->load();
    my @ids = $page->all_revision_ids();
    is(scalar(@ids), 2, '2 Revisions');
    is($page->content, "Hello\n", 'New content not saved');
}
