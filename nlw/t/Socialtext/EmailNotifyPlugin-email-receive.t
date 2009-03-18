#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Email::Send::Test;
use Socialtext::EmailNotifier;
use Socialtext::EmailReceiver::Factory;
use Test::Socialtext tests => 4;

###############################################################################
# Fixtures: clean admin
# - this test requires that it start at a clean slate
fixtures(qw( clean admin ));

$Socialtext::EmailSender::Base::SendClass = 'Test';

my $hub = new_hub('admin');

my $pages = $hub->pages;
my $notify = $hub->email_notify;
my $notifier = Socialtext::EmailNotifier->new(
    plugin           => $notify,
    notify_frequency => 'notify_frequency',
);

# used when setting mtime on varous files to force notify runs
my $ten_days_ago = time - (86400 * 10);
my $user = Socialtext::User->new( username => 'devnull1@socialtext.com' );

{
    Email::Send::Test->clear;

    Socialtext::File::update_mtime( $notifier->run_stamp_file, $ten_days_ago );
    Socialtext::File::update_mtime( $notifier->_stamp_file_for_user($user), $ten_days_ago );

    # send an email to make sure email-in causes notifications
    deliver_email('simple');

    my @emails = Email::Send::Test->emails;

    is( scalar @emails, 2, 'One email was sent' );
    is( $emails[0]->header('To'), 'devnull1@socialtext.com',
        'Email is addressed to proper recipient' );
    like( $emails[0]->header('Subject'),
          qr/\Qrecent changes in Admin Wiki workspace\E/i,
          'Subject is correct' );

    my @parts = $emails[0]->parts;
    like( $parts[0]->body, qr/this is a test message again/i,
          'Recent changes includes URI of page that was just created' );
}

# XXX - we should also test other things that should generate
# notifications, like a new page, edit page, duplicate page, send page
# to workspace, etc.

sub deliver_email {
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

    # XXX due to decoupling of postprocess email notify need to call
    # this by hand
    $notify->maybe_send_notifications;
}

