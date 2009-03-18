#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Email::Send::Test;
use Socialtext::EmailNotifier;
use Test::Socialtext tests => 1;

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
# TEST: when disabled, no e-mail notifications are sent
email_notification_sends_nothing_when_disabled: {
    my $hub  = test_hub();
    my $user = $hub->current_user();
    my $ws   = $hub->current_workspace();

    # disable e-mail notifications for our test Workspace
    $ws->update( email_notify_is_enabled => 0 );

    # create a notifier, and modify some pages
    my $notify = $hub->email_notify;
    my $notifier = Socialtext::EmailNotifier->new(
        plugin           => $notify,
        notify_frequency => 'notify_frequency'
    );
    my $pages  = $hub->pages;

    my $page_title_one = 'A New Page for Testing Email Notify';
    my $page_title_two = 'A Second Page for Testing Email Notify';

    Email::Send::Test->clear;
    Socialtext::File::update_mtime( $notifier->run_stamp_file, $long_ago );
    Socialtext::File::update_mtime( $notifier->_stamp_file_for_user($user), $long_ago );

    my $page = $pages->new_from_name($page_title_one);

    $page->content('This is the page content');
    $page->metadata->Subject($page_title_one);
    $page->metadata->update( user => $user );
    $page->store( user => $user );

    $notify->maybe_send_notifications;

    # make sure that *NO* e-mails were sent
    my @emails = Email::Send::Test->emails;
    is( scalar @emails, 0, 'No email was sent' );
}




###############################################################################
# Helper method to create a new hub for testing, with custom User+Workspace
{
    my $counter = 0;
    sub test_hub {
        $counter ++;
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
        return new_hub( $ws->name, $user->username );
    }
}
