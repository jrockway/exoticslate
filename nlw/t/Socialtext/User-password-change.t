#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext;
fixtures( 'rdbms_clean' );

BEGIN {
    unless ( eval { require Email::Send::Test; 1 } ) {
        plan skip_all => 'These tests require Email::Send::Test to run.';
    }
}

plan tests => 6;

use DateTime::Format::Pg;
use Socialtext::EmailSender;
use Socialtext::User;

Socialtext::EmailSender->TestModeOn();

my $user = Socialtext::User->create(
    username      => 'devnull9@socialtext.net',
    email_address => 'devnull9@socialtext.net',
    password      => 'password'
);

{
    $user->set_confirmation_info( is_password_change => 1 );
    $user->send_password_change_email();

    ok( $user->confirmation_is_for_password_change(),
        'confirmation_is_for_password_change() returns true' );

    my @emails = Email::Send::Test->emails();
    is( scalar @emails, 1, 'one email was sent' );
    is( $emails[0]->header('Subject'),
        'Please follow these instructions to change your Socialtext password',
        'check email subject' );
    is( $emails[0]->header('To'), $user->name_and_email(),
        'email is addressed to user' );

    my @parts = $emails[0]->parts;
    like( $parts[0]->body, qr[/submit/confirm_email\?hash=.{27}],
          'text email body has confirmation link' );
    like( $parts[1]->body, qr[/submit/confirm_email\?hash=.{27}],
          'html email body has confirmation link' );
}
