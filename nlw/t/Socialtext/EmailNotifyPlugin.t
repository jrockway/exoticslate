#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Email::Send::Test;
use Readonly;
use Test::Socialtext tests => 7;

fixtures( 'foobar' );

Readonly my $SYSTEM_EMAIL_ADDRESS => 'noreply@socialtext.com';
Readonly my $PAGE_NAME            => 'random system page';
Readonly my $PAGE_CONTENT         => 'junk';
Readonly my $EMAIL_ADDRESS        => 'devnull1@socialtext.com';
Readonly my $WORKSPACE            => 'foobar';
Readonly my $HUB                  => new_hub($WORKSPACE);

use_ok( "Socialtext::EmailNotifyPlugin" );
use_ok( "Socialtext::EmailNotifier" );

$Socialtext::EmailSender::Base::SendClass = 'Test';

create_system_user();

test_ignore_system_pages();

test_dont_notify_on_system_page();

sub test_dont_notify_on_system_page {
    my $page   = create_system_page();
    my $notify = $HUB->email_notify;
    my $notifier = Socialtext::EmailNotifier->new(plugin => $notify,
                                                  notify_frequency => 'notify_frequency');

    my $result = $notify->maybe_send_notifications();
    is( $result, 1, 'notifications attempted when no page id' );

    $result = $notify->maybe_send_notifications( $page->id );
    is( $result, undef, 'no notifications attempted when system page' );

    Email::Send::Test->clear;
    my $ten_days_ago = time - (86400 * 10);
    Socialtext::File::update_mtime( $notifier->run_stamp_file, $ten_days_ago );
    Socialtext::File::update_mtime( $notifier->_stamp_file_for_user( $HUB->current_user ),
                             $ten_days_ago );

    $page = create_non_system_page();

    $result = $notify->maybe_send_notifications( $page->id );
    is( $result, 1, 'notifications attempted when non system page' );

    my @emails = Email::Send::Test->emails;
    is( scalar @emails, 4, 'three emails were sent' );
}

sub test_ignore_system_pages {
    my $page1 = create_system_page();
    my $page2 = create_system_page( Socialtext::User->SystemUser->username );

    my $user = Socialtext::User->new( email_address => $EMAIL_ADDRESS );
    my $notify = $HUB->email_notify;
    my $notifier = Socialtext::EmailNotifier->new(plugin => $notify,
                                                  notify_frequency => 'notify_frequency');
    my $pages = $notifier->_get_all_pages( [$user] );

    my @matching_pages = map { $_->id }
        grep { $_->id eq $page1->id or $_->id eq $page2->id } @$pages;

    is_deeply(
        \@matching_pages,
        [],
        'get_all_pages does not return system pages'
    );
}

sub create_non_system_page {
    create_page( 'hello', 'monkeys', $HUB->current_user );
}

sub create_system_user {
    Socialtext::User->create( username      => $SYSTEM_EMAIL_ADDRESS,
                              email_address => $SYSTEM_EMAIL_ADDRESS,
                              password      => 'whatever',
                            );
}

sub create_system_page {
    my $username = shift || $SYSTEM_EMAIL_ADDRESS;

    my $user = Socialtext::User->new( username => $username );

    my $page = create_page( $PAGE_NAME . ':' . $username, $PAGE_CONTENT, $user );

    return $page;
}

sub create_page {
    my $name    = shift;
    my $content = shift;
    my $user    = shift;

    # Create and store the page.
    my $page = $HUB->pages->new_from_name($name);
    $page->content($content);
    $page->store( user => $user );
    return $page;
}

