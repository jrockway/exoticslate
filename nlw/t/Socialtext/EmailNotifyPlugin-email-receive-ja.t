#!perl
# @COPYRIGHT@

use strict;
use warnings;
use File::Slurp qw(slurp);
use File::Temp;
use POSIX qw(fcntl_h);
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
my $long_ago = time - (86400 * 10);    # 10 days back

###############################################################################
# TEST: receiving an e-mail in the "ja" locale
receive_email_using_ja_locale: {
    my $hub      = create_test_hub();
    my $user     = $hub->current_user();
    my $ws       = $hub->current_workspace();
    my $ws_title = $ws->title();

    # create a notifier
    my $pages    = $hub->pages;
    my $notify   = $hub->email_notify;
    my $notifier = Socialtext::EmailNotifier->new(
        plugin           => $notify,
        notify_frequency => 'notify_frequency',
    );

    Email::Send::Test->clear;

    Socialtext::File::update_mtime($notifier->run_stamp_file, $long_ago);
    Socialtext::File::update_mtime(
        $notifier->_stamp_file_for_user($user),
        $long_ago
    );

    # send an email to make sure email-in causes notifications
    deliver_email($hub, 'simple');
    $notify->maybe_send_notifications;

    # make sure that an e-mail was sent, *and* that its got the right content
    my @emails = Email::Send::Test->emails;

    is scalar @emails, 1, 'One email was sent';
    is $emails[0]->header('To'), $user->email_address,
        'Email is addressed to proper recipient';
    like $emails[0]->header('Subject'),
        qr/\Qrecent changes in $ws_title workspace\E/i, 'Subject is correct';

    my @parts = $emails[0]->parts;
    like $parts[0]->body, qr/this is a test message again/i,
        'Recent changes includes URI of page that was just created';
}

# XXX - we should also test other things that should generate
# notifications, like a new page, edit page, duplicate page, send page
# to workspace, etc.

sub deliver_email {
    my $hub  = shift;
    my $name = shift;

    # make sure that the e-mail to deliver exists
    my $file = "t/test-data/email/$name";
    die "No such email $name" unless -f $file;

    # create a temp copy of the e-mail, which comes from a User that has
    # access to the Workspace
    my $valid_email  = $hub->current_user->email_address();
    my @msg_contents = (
        "From: $valid_email\n",
        grep { !/^From: / } slurp($file)
        );

    my $fh_temp = File::Temp->new();
    $fh_temp->print(@msg_contents);
    seek($fh_temp, 0, SEEK_SET);

    # deliver the e-mail
    my $email_receiver = Socialtext::EmailReceiver::Factory->create(
        {
            locale    => 'ja',
            handle    => $fh_temp,
            workspace => $hub->current_workspace()
        }
    );

    $email_receiver->receive(
        handle    => $fh_temp,
        workspace => $hub->current_workspace(),
    );
}
