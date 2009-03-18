#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Email::Send::Test;
use Readonly;
use Socialtext::EmailNotifier;
use Socialtext::EmailNotifyPlugin;
use Test::Socialtext tests => 5;

###############################################################################
# Fixtures: db
# - need the DB around, but don't care what's in it
fixtures(qw( db ));

###############################################################################
# Make sure that any e-mails we send get captured somewhere we can get to them
$Socialtext::EmailSender::Base::SendClass = 'Test';

###############################################################################
### TEST DATA
###############################################################################
my $long_ago    = time - (86400 * 10);              # 10 days back
my $system_user = Socialtext::User->SystemUser();

# Create the "NoReply" User
# - this is a hard-coded e-mail address in ST::Page, but we need to create a
#   User object for it in order to programmatically create new pages as that
#   User.
my $noreply_user = Socialtext::User->create(
    username      => 'noreply@socialtext.com',
    email_address => 'noreply@socialtext.com',
);

###############################################################################
# TEST: e-mail notifications *ignore* system pages
ignore_system_pages: {
    my $hub  = test_hub();
    my $user = $hub->current_user();
    my $ws   = $hub->current_workspace();

    # create a notifier, and then create some pages as system-users
    my $notify   = $hub->email_notify;
    my $notifier = Socialtext::EmailNotifier->new(
        plugin           => $notify,
        notify_frequency => 'notify_frequency'
    );
    my $pages = $hub->pages;

    my $noreply_page = $pages->new_from_name('noreply_page');
    $noreply_page->content('junk');
    $noreply_page->store(user => $noreply_user);

    my $system_page = $pages->new_from_name('system_page');
    $system_page->content('junk');
    $system_page->store(user => $system_user);

    # make sure that our system pages are *NOT* in the list of pages that
    # could be notified on
    my $all_pages = $notifier->_get_all_pages([$user]);
    my @matching_pages = map { $_->id }
        grep { $_->id eq $noreply_page->id or $_->id eq $system_page->id }
        @{$all_pages};

    is_deeply(
        \@matching_pages,
        [],
        '_get_all_pages does not return system pages'
    );
}

###############################################################################
# TEST: don't notify on system pages
no_notification_on_system_pages: {
    my $hub  = test_hub();
    my $user = $hub->current_user();
    my $ws   = $hub->current_workspace();

    # create a notifier
    my $notify   = $hub->email_notify;
    my $notifier = Socialtext::EmailNotifier->new(
        plugin           => $notify,
        notify_frequency => 'notify_frequency'
    );

    # create a single page as a system-user
    my $pages = $hub->pages;

    my $system_page = $pages->new_from_name('system_page');
    $system_page->content('junk');
    $system_page->store(user => $system_user);

    # make sure that we send notification without a Page Id
    my $result = $notify->maybe_send_notifications();
    is($result, 1, 'notifications attempted when no page id');

    # make sure that we *don't* send notifications for system pages
    $result = $notify->maybe_send_notifications($system_page->id);
    is($result, undef, 'no notifications attempted when system page');

    # reset the notifier
    Email::Send::Test->clear;
    Socialtext::File::update_mtime($notifier->run_stamp_file, $long_ago);
    Socialtext::File::update_mtime(
        $notifier->_stamp_file_for_user($user),
        $long_ago
    );

    # create a page, normally (as a regular user)
    my $normal_page = $pages->new_from_name('regular_page');
    $normal_page->content('junk');
    $normal_page->store(user => $user);

    # make sure that we send notifications for non-system pages
    $result = $notify->maybe_send_notifications($normal_page->id);
    is($result, 1, 'notifications attempted when non system page');

    my @emails = Email::Send::Test->emails;
    is(scalar @emails, 1, 'one email was sent');
}

###############################################################################
# Helper method to create a new hub for testing, with custom User+Workspace
{
    my $counter = 0;

    sub test_hub {
        $counter++;
        my $unique_id = time . $$ . $counter;

        # create a new test User
        my $user = Socialtext::User->create(
            username      => $unique_id . '@ken.socialtext.net',
            email_address => $unique_id . '@ken.socialtext.net',
        );

        # create a new test Workspace
        my $ws = Socialtext::Workspace->create(
            name               => $unique_id,
            title              => $unique_id,
            created_by_user_id => $user->user_id,
            account_id         => Socialtext::Account->Default->account_id,
            skip_default_pages => 1,
        );

        # create a new Hub based on this WS/User, and return that back to the
        # caller
        return new_hub($ws->name, $user->username);
    }
}
