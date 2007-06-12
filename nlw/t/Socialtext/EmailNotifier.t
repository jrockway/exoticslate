#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext;
fixtures( 'foobar' );

plan tests => 3;

use Readonly;

Readonly my $SYSTEM_EMAIL_ADDRESS => 'noreply@socialtext.com';
Readonly my $PAGE_NAME            => 'random system page';
Readonly my $PAGE_CONTENT         => 'junk';
Readonly my $EMAIL_ADDRESS        => 'devnull1@socialtext.com';
Readonly my $WORKSPACE            => 'foobar';
Readonly my $HUB                  => new_hub($WORKSPACE);

use_ok( "Socialtext::EmailNotifier" );

{
    my $user = Socialtext::User->create(
        username      => $SYSTEM_EMAIL_ADDRESS,
        email_address => $SYSTEM_EMAIL_ADDRESS,
        password      => 'whatever',
    );

    my $notify = $HUB->email_notify;
    my $notifier = Socialtext::EmailNotifier->new(plugin => $notify,
                                                  notify_frequency => 'notify_frequency');
    $user->set_confirmation_info(is_password_change => 0);
    my $ready = $notifier->_user_ready($user);
    is ($ready, undef, 'User is not ready');

    $user->confirm_email_address();
    $ready = $notifier->_user_ready($user);
    is ($ready, 1, 'user is ready');
}
