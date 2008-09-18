#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 25;
fixtures( 'rdbms_clean' );

use Socialtext::User;

my $user;

# Since the Postgres plugin is always available, these are duplicated here
is( Socialtext::User->Count(), 2, 'base users are registered' );
ok( Socialtext::User->SystemUser, 'a system user exists' );
ok( Socialtext::User->Guest, 'a guest user exists' );
is( Socialtext::User->Guest->primary_account->name, 'Socialtext',
    'Guest user has correct account' );

$user = Socialtext::User->new( username => 'devnull9@socialtext.net', );
is( $user, undef, 'no non-special users exist yet' );

$user = Socialtext::User->SystemUser;

is( $user->driver_name, 'Default',
    'System User is stored in Postgres (Default).'
);

is( $user->creator->username, 'system-user',
    'System User sprang from suigenesis.'
);
is( $user->primary_account->name, 'Socialtext',
    'System user has correct account',
);

my $new_user = Socialtext::User->create(
    username      => 'devnull1@socialtext.com',
    first_name    => 'Dev',
    last_name     => 'Null',
    email_address => 'devnull1@socialtext.com',
    password      => 'd3vnu11l'
);

is( $new_user->creator->username, 'system-user',
    'Unidentified creators default to system-user.'
);

my $newer_user = Socialtext::User->create(
    username           => 'devnull2@socialtext.com',
    first_name         => 'Dev',
    last_name          => 'Null 2',
    email_address      => 'devnull2@socialtext.com',
    password           => 'password',
    created_by_user_id => $new_user->user_id
);

is( $newer_user->creator->username, 'devnull1@socialtext.com',
    'Tracking creator.'
);

ok( $newer_user->password_is_correct( 'password' ),
    'Password checks out.'
);

ok( $newer_user->update_store( last_name => 'Nullius' ),
    'Can update certain data (like last name).'
);

is( $newer_user->last_name, 'Nullius',
    'And when updated, the instance retains the new value' );

ok( !$newer_user->is_business_admin,
    "By default, users aren't business admins" );

ok( $newer_user->set_business_admin(1), "But they can be made to be." );

ok( $newer_user->is_business_admin(),
    "And when they are, the instance is updated." );

my $user3 = Socialtext::User->create(
    username      => 'nonauth@socialtext.net',
    email_address => 'nonauth@socialtext.net',
    password      => 'unencrypted',
    no_crypt      => 1,
    created_by_user_id => $user->user_id,
);

$user3->set_confirmation_info(is_password_change => 0);

is( $user3->requires_confirmation, 1, 'user requires confirmation' );

email_hiding_by_account :
{
    my $visible_account = Socialtext::Account->create(
        name => 'visible_account',
    );
    my $hidden_account = Socialtext::Account->create(
        name => 'hidden_account',
    );

    my $hidden_workspace = Socialtext::Workspace->create(
        name       => 'hidden_workspace',
        title      => 'Hidden Workspace',
        account_id => $hidden_account->account_id,
    );
    my $visible_workspace = Socialtext::Workspace->create(
        name       => 'visible_workspace',
        title      => 'visible Workspace',
        account_id => $visible_account->account_id,
    );

    $hidden_account->update(email_addresses_are_hidden => 1);
    $hidden_workspace->update(email_addresses_are_hidden => 1);

    my $personA = Socialtext::User->create(
        username           => 'person.a@socialtext.com',
        first_name         => 'Person',
        last_name          => 'A',
        email_address      => 'person.a@socialtext.com',
        password           => 'password',
        created_by_user_id => Socialtext::User->SystemUser->user_id,
    );

    my $personB = Socialtext::User->create(
        username           => 'person.b@socialtext.com',
        first_name         => 'Person',
        last_name          => 'B',
        email_address      => 'person.b@socialtext.com',
        created_by_user_id => Socialtext::User->SystemUser->user_id,
    );

    # primary = hidden == hidden

    $personA->primary_account($hidden_account->account_id);
    $personB->primary_account($hidden_account->account_id);

    is $personA->masked_email_address(user => $personB),
       'person.a@hidden',
       'primary = hidden == hidden';
    is $personB->masked_email_address(user => $personA),
       'person.b@hidden',
       'primary = hidden == hidden';

    # primary = hidden + secondary = visible == visible

    $visible_workspace->add_user(user => $personA);
    $visible_workspace->add_user(user => $personB);

    is $personA->masked_email_address(user => $personB),
       'person.a@socialtext.com',
       'primary = hidden + secondary = visible == visible';
    is $personB->masked_email_address(user => $personA),
       'person.b@socialtext.com',
       'primary = hidden + secondary = visible == visible';

    # primary = visible + secondary = visible == visible

    $personA->primary_account($visible_account->account_id);
    $personB->primary_account($visible_account->account_id);

    is $personA->masked_email_address(user => $personB),
       'person.a@socialtext.com',
       'primary = visible == visible';
    is $personB->masked_email_address(user => $personA),
       'person.b@socialtext.com',
       'primary = visible == visible';

    # primary = visible + secondary = visible == visible

    $visible_workspace->remove_user(user => $personA);
    $visible_workspace->remove_user(user => $personB);

    is $personA->masked_email_address(user => $personB),
       'person.a@socialtext.com',
       'primary = visible + secondary = visible == visible';
    is $personB->masked_email_address(user => $personA),
       'person.b@socialtext.com',
       'primary = visible + secondary = visible == visible';
}
