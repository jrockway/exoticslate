#!perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More;
use mocked 'Apache';
use mocked 'Apache::Cookie';
use mocked 'Socialtext::Events', qw( event_ok is_event_count );

use Test::Socialtext tests => 50;
use Socialtext::Signal;

fixtures( 'admin_no_pages' );

BEGIN {
    use_ok( 'Socialtext::EditPlugin' );
}

my $save_revision_id;

my $hub = new_hub('admin');
my $user  = $hub->current_user;
$user->update_store(
    first_name => "Master",
    last_name => "Shake",
);
my $page_title = 'Save Page';
my $page_id = 'save_page';
my $page = Socialtext::Page->new( hub => $hub )->create(
    title   => $page_title,
    content => 'First Paragraph',
    creator => $hub->current_user,
);
$save_revision_id = $page->revision_id;
@Socialtext::Events::Events = ();

edit_summary: {
    my $hub = setup_page(
        revision_id  => $save_revision_id,
        edit_summary => ' i suck at typing  ',
    );

    $hub->edit->edit_content;
    my $page = Socialtext::Page->new(hub => $hub, id => $page_id)->load();
    is $page->content, "this is a page body\n";
    is $page->metadata->RevisionSummary, 'i suck at typing',
        "edit summary was saved";
    is $page->edit_summary, 'i suck at typing', 'proxy method works';
    $save_revision_id = $page->revision_id;
    event_ok(
        event_class => 'page',
        action      => 'edit_save',
    );
    is_event_count(0);
}

edit_summary_via_save: {
    my $hub = setup_page(
        revision_id => $save_revision_id,
        edit_summary => ' i was not put on this earth to listen to meat     ',
        original_page_id => $page_id,
    );

    $hub->edit->save;
    my $page = Socialtext::Page->new(hub => $hub, id => $page_id)->load();
    is $page->content, "this is a page body\n";
    is $page->metadata->RevisionSummary, 'i was not put on this earth to listen to meat', "edit summary was saved";
    is $page->edit_summary, 'i was not put on this earth to listen to meat', 'proxy method works';
    $save_revision_id = $page->revision_id;
    event_ok (
        event_class => 'page',
        action => 'edit_save',
    );
    is_event_count(0);
}

edit_summary_signal: {
    my $hub = setup_page(
        revision_id => $save_revision_id,
        edit_summary => 'where you at, dog',
        signal_edit_summary => 1,
    );

    my $return = $hub->edit->edit_content;
    my $page = Socialtext::Page->new(hub => $hub, id => $page_id)->load();

    is $page->content, "this is a page body\n";
    is $page->metadata->RevisionSummary, 'where you at, dog',
        "edit summary was saved";
    is $page->edit_summary, 'where you at, dog', 'accessor method works';
    $save_revision_id = $page->revision_id;

    signal_ok (
        viewer => $hub->current_user,
        body => $user->best_full_name .', "where you at, dog" (edited Save Page in Admin Wiki)',
        signaler => $hub->current_user,
        topic => {
            page_id => $page_id,
            workspace_id => $hub->current_workspace->workspace_id,
        },
        msg => 'normal length edit summary'
    );
    event_ok (
        event_class => 'signal',
        action => 'page_edit',
    );
    event_ok (
        event_class => 'page',
        action => 'edit_save',
    );
    is_event_count(0);
}

long_edit_summary_signal: {
    my $hub = setup_page(
        revision_id => $save_revision_id,
        edit_summary => 'ten chars!' x 13 . 'we are over the limit now',
        signal_edit_summary => 1,
    );

    my $return = $hub->edit->edit_content;
    my $page = Socialtext::Page->new(hub => $hub, id => $page_id)->load();

    $save_revision_id = $page->revision_id;

    signal_ok (
        viewer => $hub->current_user,
        body => $user->best_full_name . ', "' . 'ten chars!' x 13 . 'we are..." (edited Save Page in Admin Wiki)',
        signaler => $hub->current_user,
        topic => {
            page_id => $page_id,
            workspace_id => $hub->current_workspace->workspace_id,
        },
        msg => 'edit summary over max signal length'
    );
    event_ok (
        event_class => 'signal',
        action => 'page_edit',
    );
    event_ok (
        event_class => 'page',
        action => 'edit_save',
    );
    is_event_count(0);
}

no_edit_summary_signal: {
    my $hub = setup_page(
        revision_id => $save_revision_id,
        edit_summary => '',
        signal_edit_summary => 1,
    );
    $hub->edit->edit_content;
    my $page = Socialtext::Page->new(hub => $hub, id => $page_id)->load();
    $save_revision_id = $page->revision_id;

    signal_ok (
        viewer => $user,
        body => $user->best_full_name . ' wants you to know about an edit of Save Page in Admin Wiki',
        signaler => $user,
        topic => {
            page_id => $page_id,
            workspace_id => $hub->current_workspace->workspace_id,
        },
        msg => 'edit summary over max signal length'
    );
    Socialtext::Events::event_ok (
        event_class => 'signal',
        action => 'page_edit',
    );
    Socialtext::Events::event_ok (
        event_class => 'page',
        action => 'edit_save',
    );
    is_event_count(0);
}

signals_disabled_signal_edit_summary: {
    $user->primary_account->disable_plugin('signals');
    my $hub ;
    eval {
        $hub = setup_page(
            revision_id => $save_revision_id,
            edit_summary => 'Dancing is forbidden!',
            signal_edit_summary => 1,
        );
        $hub->edit->edit_content;
        my $page = Socialtext::Page->new(hub => $hub, id => $page_id)->load();
        $save_revision_id = $page->revision_id;
        is_signal_count(0);
        Socialtext::Events::event_ok (
            event_class => 'page',
            action => 'edit_save',
        );
        is_event_count(0);
    };
    ok !$@;
    $user->primary_account->enable_plugin('signals');
}

exit;

sub signal_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my %opts = @_;
    my @signals = Socialtext::Signal->All(viewer => $opts{viewer});
    ok scalar(@signals), "$opts{msg} - got signal(s)";
    ok my $topic = $signals[0]->topic, "$opts{msg} - got topic";
    is $topic->{workspace_id}, $opts{topic}{workspace_id},
        "$opts{msg} - got the correct workspace";
    is $topic->{page_id}, $opts{topic}{page_id}, "$opts{msg} - got the correct page";
    is $signals[0]->body, $opts{body}, "$opts{msg} - signal body ok";
}

sub is_signal_count {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    return scalar(Socialtext::Signal->All(viewer => $user));
}

sub setup_page {
    my %opts = @_;
    my %defaults = (
        revision_id => undef,
        page_name => $page_title,
        page_body => 'this is a page body',
        subject => $page_title,
        action => 'edit_save',
        caller_action => '',
        append_mode => '',
        page_body_decoy => 'Decoy',
        edit_summary => '',
        signal_edit_summary => 0,
        original_page_id => ''
    );
    my $hub = new_hub('admin');
    my $cgi = $hub->rest->query;
    map { $cgi->param($_, $opts{$_} || $defaults{$_}) } keys %defaults;
    return $hub;
}
