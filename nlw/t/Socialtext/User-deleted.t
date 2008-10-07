#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 12;
fixtures('populated_rdbms');

use Socialtext::User;
use Socialtext::UserId;
use Socialtext::User::Default::Factory;

{
    my $users = Socialtext::User->All();
    is_deeply(
        [ map { $_->username } $users->all() ],
        [
            ( map { ("devnull$_\@urth.org") } 1 .. 7 ),
             'guest', 'system-user'
        ],
        'Got the minimum 9 users this fixture starts with.',
    );
}

# populate a user that doesn't currently exist, even though it uses a
# known driver.
my $unique_id = Socialtext::UserId->SystemUniqueId();
my $user_id = Socialtext::UserId->create(
    system_unique_id => $unique_id,
    driver_key       => 'Default',
    driver_unique_id => 999999,
    driver_username  => "Nemo",
);

{
    is (Socialtext::User->Count, 10, "New user added only to UserId, simulating adding and deleting from the store.");
    my $nemo = Socialtext::User->new( user_id => $user_id->system_unique_id );
    ok ($nemo->to_hash, "Nemo can be hashified" );
    is ($nemo->username, 'Nemo', "Nemo was found, no error.");
    is ($nemo->first_name, 'Deleted', "But he's still deleted.");
}

{
    my $nonexistent = Socialtext::User->new( username => 'dracula' );
    is( $nonexistent, undef,
        "For users that didn't exist, they're still undef." );
}

# Move the back-end record, so that user_id is out of sync with the UserId
# table. We should still be able to find this user and treat him the same (he
# should still have the same system_unique_id)
{
    my $existing = Socialtext::User::Default::Factory->new->GetUser(
        username => 'devnull1@urth.org',
    );
    my $old_user_id = $existing->user_id;
    $existing->update( user_id => 9999 );
    my $moved = Socialtext::User->new( user_id => $old_user_id );
    is( $moved->username, $existing->username, "Moved user still findable" );
    is( $moved->homunculus->user_id, 9999, "Updated its UserId record, too" );
    my $no_longer_there = Socialtext::UserId->new(
        driver_key       => $existing->driver_name,
        driver_unique_id => $old_user_id
    );
    is( $no_longer_there, undef,
        "Old user_id is wiped out of the UserId table."
    );
}

# Deleted LDAP users sometimes don't end up with a username
# so we should provide a default one, as other parts of the 
# system ass-u-me that everyone has a username.
Default_username: {
    # Create a UserId, but no User, to trick the system into thinking
    # this is a deleted user.
    my $id = Socialtext::UserId->SystemUniqueId();
    Socialtext::UserId->create(
        system_unique_id => $id,
        driver_key       => 'Default',
        driver_unique_id => "Rubber Bands",
        driver_username  => '',
    );

    my $nemo = Socialtext::User->new( user_id => $id );
    ok ($nemo->to_hash, "deleted user can be hashified" );
    is ($nemo->username, 'deleted-user', "user was found, no error.");
    is ($nemo->first_name, 'Deleted', "But he's still deleted.");
}
