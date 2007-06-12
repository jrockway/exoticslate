#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 14;
fixtures( 'rdbms_clean' );

use DateTime::Format::Pg;
use Socialtext::User::Default;

my $user;

# Test initial users that we always have available
is( Socialtext::User::Default->Count(), 2, 'expected to find two users' );
ok( Socialtext::User::Default->new( username => 'system-user' ),
    'system user exists' );
ok( Socialtext::User::Default->new( username => 'guest' ),
    'guest user exists' );

$user = Socialtext::User::Default->new(
    username => 'devnull9@socialtext.net',
);
is( $user, undef, 'the bogus user does not exist yet' );

my $now = DateTime->now( time_zone => 'UTC' );
$user = Socialtext::User::Default->create(
    username      => 'devnull9@socialtext.net',
    email_address => 'devnull9@socialtext.net',
    password      => 'password'
);
ok( $user, 'create returned a new user' );
is(
    $user->username, 'devnull9@socialtext.net',
    "new user's username matches the email address passed in to create"
);
ok( $user->password_is_correct('password'), 'password_is_correct() works' );

is( Socialtext::User::Default->Count(), 3, 'expected to find three users' );

my $user2 = Socialtext::User::Default->create(
    username           => 'devnull8@socialtext.net',
    email_address      => 'devnull8@socialtext.net',
    password           => 'unencrypted',
    no_crypt           => 1,
);

is( $user2->password, 'unencrypted', 'password was not passed to crypt()' );

ok(
    Socialtext::User::Default->new( username => 'DEVNULL8@socialtext.NET' ),
    'lookup by username is case insensitive'
);

$user = Socialtext::User::Default->create(
    username      => 'DEVNULL7@socialtext.net',
    email_address => ' devnull7@SOCIALTEXT.NET  ',
    password      => 'foobar',
);

is(
    $user->username, 'devnull7@socialtext.net',
    'username is always returned in lower case'
);

is(
    $user->email_address, 'devnull7@socialtext.net',
    'email address is always returned in lower case'
);

eval {
    Socialtext::User::Default->new( username => 'system-user' )
        ->update( username => 'foobar' );
};
like( $@, qr/cannot change/,
    'cannot change the username of a system-created user' );

eval {
    Socialtext::User::Default->new( username => 'system-user' )
        ->update( email_address => 'foobar@example.com' );
};
like( $@, qr/cannot change/,
    'cannot change the email address of a system-created user' );
