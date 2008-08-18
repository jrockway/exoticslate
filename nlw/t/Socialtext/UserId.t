#!/usr/bin/env perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 6;

BEGIN {
    use_ok( 'Socialtext::UserId' );
}

fixtures( 'db' );

my $homunculus = FakeHomunculus->new(
    driver_key  => 'Fake',
    user_id     => 1,
    username    => 'faky@faker.com'
);

is(
    Socialtext::UserId->new(
        driver_key       => 'Fake',
        driver_unique_id => 1
    ),
    undef,
    "UserId record doesn't exist yet"
);

my $user_id1 = Socialtext::UserId->create_if_necessary( $homunculus );
isa_ok(
    Socialtext::UserId->new(
        driver_key       => 'Fake',
        driver_unique_id => 1
    ),
    'Socialtext::UserId',
    "Once populated opportunistically, we can look up the local user record."
);

is( $user_id1->driver_username, 'faky@faker.com', "We cache the username." );

$homunculus->username( 'fakir@faker.com' );

my $user_id2 = Socialtext::UserId->create_if_necessary( $homunculus );
is(
    $user_id1->system_unique_id, $user_id2->system_unique_id,
    "Two user records representing the same user"
);

is( $user_id2->driver_username, 'fakir@faker.com',
    "Opportunistically grabbed the new username" );

# cleanup 
$user_id1->delete();
$user_id2->delete();

exit;


package FakeHomunculus;

use Class::Field 'field';

BEGIN {
    field 'driver_key';
    field 'user_id';
    field 'username';
}

sub new {
    my ( $class, %p ) = @_;
    return bless {
        driver_key  => $p{driver_key},
        user_id     => $p{user_id},
        username    => $p{username}
    }, $class;
}

1;
