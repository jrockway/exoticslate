#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 1;
fixtures( 'admin' );
use Email::Send::Test;
use Socialtext::EmailNotifier;

$Socialtext::EmailSender::Base::SendClass = 'Test';
my $ten_days_ago = time - (86400 * 10);
my $hub = new_hub('admin');

# used when setting mtime on varous files to force notify runs
my $user = Socialtext::User->new( username => 'devnull1@socialtext.com' );
$hub->preferences->store( 'devnull1@socialtext.com', email_notify => { notify_frequency => 0 } );
$hub->preferences->store( 'q@q.q', email_notify => { notify_frequency => 0 } );

$hub->current_workspace->update( email_notify_is_enabled => 1 );

my $notify = $hub->email_notify;
my $notifier = Socialtext::EmailNotifier->new(
    plugin           => $notify,
    notify_frequency => 'notify_frequency'
);

my $pages  = $hub->pages;

my $page_title_one = 'A New Page for Testing Email Notify';
my $page_title_two = 'A New Page for Testing Email Notify';

Email::Send::Test->clear;
Socialtext::File::update_mtime( $notifier->run_stamp_file, $ten_days_ago );
Socialtext::File::update_mtime( $notifier->_stamp_file_for_user($user), $ten_days_ago );

my $page = $pages->new_from_name($page_title_one);

$page->content('This is the page content');
$page->metadata->Subject($page_title_one);
$page->metadata->update( user => $hub->current_user );
$page->store( user => $hub->current_user );

$notify->maybe_send_notifications;
my @emails = Email::Send::Test->emails;

is( scalar @emails, 0, 'No email was sent' );

