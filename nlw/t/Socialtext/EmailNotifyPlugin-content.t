#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Email::Send::Test;
use Socialtext::EmailNotifier;
use Test::Socialtext tests => 10;

fixtures( 'admin' );

$Socialtext::EmailSender::Base::SendClass = 'Test';

# used when setting mtime on varous files to force notify runs
my $ten_days_ago = time - (86400 * 10);
my $user = Socialtext::User->new( username => 'devnull1@socialtext.com' );

{
    my $hub      = new_hub('admin');
    my $notify   = $hub->email_notify;
    my $notifier = Socialtext::EmailNotifier->new(
        plugin           => $notify,
        notify_frequency => 'notify_frequency'
    );
    my $pages          = $hub->pages;
    my $page_title_one = 'A New Page for Testing Email Notify';
    my $page_title_two = 'A Second Page for Testing Email Notify';

    Email::Send::Test->clear;
    Socialtext::File::update_mtime( $notifier->run_stamp_file, $ten_days_ago );
    Socialtext::File::update_mtime( $notifier->_stamp_file_for_user($user),
        $ten_days_ago );

    my $page = Socialtext::Page->new( hub => $hub )->create(
        title   => $page_title_one,
        content => 'This is the page content',
        creator => $hub->current_user,
        date    => DateTime->now->add( seconds => 30 ),
    );
    my $page2 = Socialtext::Page->new( hub => $hub )->create(
        title   => $page_title_two,
        content => 'This is the other content',
        creator => $hub->current_user,
        date    => DateTime->now->add( seconds => 60 ),
    );

    $notify->maybe_send_notifications;

    my @emails = Email::Send::Test->emails;

    is(scalar @emails, 2, 'One email was sent');
    is(
        $emails[0]->header('To'), 'devnull1@socialtext.com',
        'Email is addressed to proper recipient'
    );
    like(
        $emails[0]->header('Subject'),
        qr/\Qrecent changes in Admin Wiki workspace\E/i,
        'Subject is correct'
    );
    is(
        $emails[0]->header('From'),
        q{"} . $hub->current_workspace->title . q{" <noreply@socialtext.com>},
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
        qr{admin/emailprefs},
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

{
    my $hub = new_hub('admin');
    my $notify = $hub->email_notify;
    my $pages  = $hub->pages;
    my $notifier = Socialtext::EmailNotifier->new(
        plugin           => $notify,
        notify_frequency => 'notify_frequency'
    );
    Email::Send::Test->clear;
    Socialtext::File::update_mtime( $notifier->run_stamp_file, $ten_days_ago );
    Socialtext::File::update_mtime( $notifier->_stamp_file_for_user($user), $ten_days_ago );

    my $page = $pages->new_from_name('A New Page for Testing Email Notify');

    $page->delete( user => $hub->current_user );

    $notify->maybe_send_notifications;

    my @emails = Email::Send::Test->emails;

    # There may be an email because of all the "default" pages
    # belonging to a workspace.  Depending on how quick the tests run
    # they may be less than 10 seconds old.
    if (@emails)
    {
        my @parts = $emails[0]->parts;

        my $page_uri = $page->uri;
        unlike( $parts[0]->body, qr/\Q$page_uri\E/i,
                'Recent changes email does not include URI for deleted page.' );
    }
    else
    {
        is( scalar @emails, 0,
            'No email was sent for a deleted page.' );
    }
}

