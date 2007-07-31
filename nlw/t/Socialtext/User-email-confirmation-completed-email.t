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

plan tests => 8;

use Socialtext::Account;
use Socialtext::User;
use Socialtext::Workspace;

$Socialtext::EmailSender::Base::SendClass = 'Test';

my $user = Socialtext::User->create(
    username      => 'devnull9@socialtext.net',
    email_address => 'devnull9@socialtext.net',
    password      => 'password'
);

{
    $user->set_confirmation_info();

    my @emails = Email::Send::Test->emails();
    is( scalar @emails, 0, 'no email was sent while user still requires confirmation' );

    $user->confirm_email_address();
    @emails = Email::Send::Test->emails();
    is( scalar @emails, 1, 'one email was sent when user was confirmed' );
    is( $emails[0]->header('Subject'),
        'You can now login to the Socialtext application',
        'check email subject - user is in no workspaces' );
    is( $emails[0]->header('To'), $user->name_and_email(),
        'email is addressed to user' );

    my @parts = $emails[0]->parts;
    like( $parts[0]->body, qr[/nlw/login\.html],
          'text email body has login link' );
}

{
    Email::Send::Test->clear();

    my $ws = Socialtext::Workspace->create(
        name               => 'test',
        title              => 'Test WS',
        skip_default_pages => 1,
        account_id         => Socialtext::Account->Socialtext()->account_id(),
    );
    $ws->add_user( user => $user );

    $user->set_confirmation_info();
    $user->confirm_email_address();

    my @emails = Email::Send::Test->emails();
    is( scalar @emails, 1, 'one email was sent when user was confirmed' );
    is( $emails[0]->header('Subject'),
        'You can now login to the Test WS workspace',
        'check email subject - user is in a workspace' );

    my @parts = $emails[0]->parts;
    like( $parts[0]->body, qr[/test/],
          'text email body has link to workspace' );
}
