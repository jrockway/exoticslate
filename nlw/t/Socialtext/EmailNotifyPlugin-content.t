#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Email::Send::Test;
use Socialtext::EmailNotifier;
use Test::Socialtext tests => 10;

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
my $long_ago = time - (86400 * 10);                 # 10 days back

###############################################################################
# TEST: e-mail notifications are sent
email_notifications_send_emails: {
    my $hub      = test_hub();
    my $user     = $hub->current_user();
    my $ws       = $hub->current_workspace();
    my $ws_title = $ws->title();

    # create a notifier, and modify some pages
    my $notify   = $hub->email_notify;
    my $notifier = Socialtext::EmailNotifier->new(
        plugin           => $notify,
        notify_frequency => 'notify_frequency'
    );
    my $pages          = $hub->pages;
    my $page_title_one = 'A New Page for Testing Email Notify';
    my $page_title_two = 'A Second Page for Testing Email Notify';

    Email::Send::Test->clear;
    Socialtext::File::update_mtime($notifier->run_stamp_file, $long_ago);
    Socialtext::File::update_mtime(
        $notifier->_stamp_file_for_user($user),
        $long_ago
    );

    my $page = Socialtext::Page->new(hub => $hub)->create(
        title   => $page_title_one,
        content => 'This is the page content',
        creator => $user,
        date    => DateTime->now->add(seconds => 30),
    );
    my $page2 = Socialtext::Page->new(hub => $hub)->create(
        title   => $page_title_two,
        content => 'This is the other content',
        creator => $user,
        date    => DateTime->now->add(seconds => 60),
    );

    $notify->maybe_send_notifications;

    # make sure that an e-mail was sent, *and* that its got the right content
    my @emails = Email::Send::Test->emails;

    is(scalar @emails, 1, 'One email was sent');
    is(
        $emails[0]->header('To'), $user->email_address,
        'Email is addressed to proper recipient'
    );
    like(
        $emails[0]->header('Subject'),
        qr/\Qrecent changes in $ws_title workspace\E/i,
        'Subject is correct'
    );
    is(
        $emails[0]->header('From'),
        q{"} . $ws_title . q{" <noreply@socialtext.com>},
        'From is correct'
    );

    my @parts = $emails[0]->parts;

    my $page_uri = $page->uri;

    for my $part (@parts) {
        like(
            $part->body, qr/\Q$page_uri\E/i,
            'Recent changes includes URI of page that was just created'
        );
    }

    like(
        $parts[0]->body,
        qr{$ws_title/emailprefs},
        'Preferences url action is correct'
    );

    like(
        $parts[0]->body,
        qr{\n$page_title_one\n  http},
        'First page title correct'
    );

    like(
        $parts[0]->body,
        qr{\n$page_title_two\n  http},
        'Second page title correct'
    );

    # XXX shouldn't the user get things in their own timezone
    #    like(
    #        $parts[0]->body,
    #        qr{GMT\)\n\n$page_title_two\n},
    #        'Only one blank line between entries'
    #    );
}

###############################################################################
# TEST: deleting a page does *not* send an e-mail notification
no_email_notification_on_page_delete: {
    my $hub  = test_hub();
    my $user = $hub->current_user();

    # create a notifier, and delete a page
    my $notify   = $hub->email_notify;
    my $pages    = $hub->pages;
    my $notifier = Socialtext::EmailNotifier->new(
        plugin           => $notify,
        notify_frequency => 'notify_frequency'
    );
    Email::Send::Test->clear;
    Socialtext::File::update_mtime($notifier->run_stamp_file, $long_ago);
    Socialtext::File::update_mtime($notifier->_stamp_file_for_user($user),
        $long_ago);

    my $page = $pages->new_from_name('A New Page for Testing Email Notify');

    $page->delete(user => $user);

    $notify->maybe_send_notifications;

    # make sure that *no* e-mail was sent
    my @emails = Email::Send::Test->emails;

    is(scalar @emails, 0, 'No email was sent for a deleted page.');
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
