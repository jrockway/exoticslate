#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Email::Send::Test;
use Socialtext::EmailNotifier;
use Socialtext::EmailReceiver::Factory;
use Test::Socialtext tests => 4;

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
# TEST: receiving an e-mail
receive_email: {
    my $hub      = test_hub();
    my $user     = $hub->current_user();
    my $ws       = $hub->current_workspace();
    my $ws_title = $ws->title();

    # create a notifier
    my $pages = $hub->pages;
    my $notify = $hub->email_notify;
    my $notifier = Socialtext::EmailNotifier->new(
        plugin           => $notify,
        notify_frequency => 'notify_frequency',
    );

    Email::Send::Test->clear;

    Socialtext::File::update_mtime( $notifier->run_stamp_file, $long_ago );
    Socialtext::File::update_mtime( $notifier->_stamp_file_for_user($user), $long_ago );

    # send an email to make sure email-in causes notifications
    deliver_email($hub, 'simple');
    $notify->maybe_send_notifications;

    # make sure that an e-mail was send, *and* that its got the right content
    my @emails = Email::Send::Test->emails;

    is( scalar @emails, 1, 'One email was sent' );
    is( $emails[0]->header('To'), $user->email_address,
        'Email is addressed to proper recipient' );
    like( $emails[0]->header('Subject'),
          qr/\Qrecent changes in $ws_title workspace\E/i,
          'Subject is correct' );

    my @parts = $emails[0]->parts;
    like( $parts[0]->body, qr/this is a test message again/i,
          'Recent changes includes URI of page that was just created' );
}

# XXX - we should also test other things that should generate
# notifications, like a new page, edit page, duplicate page, send page
# to workspace, etc.

sub deliver_email {
    my $hub  = shift;
    my $name = shift;

    my $file = "t/test-data/email/$name";
    die "No such email $name" unless -f $file;

    open my $fh, '<', $file or die $!;

    my $email_receiver = Socialtext::EmailReceiver::Factory->create(
                {
                    locale => 'en',
                    handle => $fh,
                    workspace => $hub->current_workspace
                });
    $email_receiver->receive();
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
