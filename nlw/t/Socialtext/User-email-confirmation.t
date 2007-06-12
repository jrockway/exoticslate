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

plan tests => 11;

use Socialtext::EmailSender;
use Socialtext::User;

Socialtext::EmailSender->TestModeOn();

my $user = Socialtext::User->create(
    username      => 'devnull9@socialtext.net',
    email_address => 'devnull9@socialtext.net',
    password      => 'password'
);

{
    $user->set_confirmation_info();

    is( length $user->confirmation_hash(), 27,
        'user has a base64 encoded email confirmation hash' );
    ok( $user->requires_confirmation(),
        'requires_confirmation() returns true' );
    ok( ! $user->confirmation_has_expired(),
        'confirmation has not yet expired' );
    ok( ! $user->confirmation_is_for_password_change(),
        'confirmation_is_for_password_change() returns false' );

    $user->confirm_email_address();
    ok( ! $user->requires_confirmation(),
        'requires_confirmation() returns false after calling confirm_email_address()' );

}

RT20767_REUSE_HASH: {
    $user->set_confirmation_info();
    my $hash1 = $user->confirmation_hash();

    sleep 2; # Hash contains time(), which we want to make sure has changed.

    $user->set_confirmation_info();
    my $hash2 = $user->confirmation_hash();

    is(
        $hash1, $hash2,
        'Confirmation hash for a user gets reusued if it exists'
    );
}

{
    Email::Send::Test->clear();

    $user->set_confirmation_info();
    $user->send_confirmation_email();

    my @emails = Email::Send::Test->emails();
    is( scalar @emails, 1, 'one email was sent' );
    is( $emails[0]->header('Subject'),
        'Please confirm your email address to register with Socialtext',
        'check email subject' );
    is( $emails[0]->header('To'), $user->name_and_email(),
        'email is addressed to user' );

    my @parts = $emails[0]->parts;
    like( $parts[0]->body, qr[/submit/confirm_email\?hash=.{27}],
          'text email body has confirmation link' );
    like( $parts[1]->body, qr[/submit/confirm_email\?hash=.{27}],
          'html email body has confirmation link' );
}
