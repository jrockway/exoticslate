#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Socialtext::User;
use Test::Socialtext tests => 13;

fixtures('db');

###############################################################################
# non-existent users shouldn't ever exist, no matter what
non_existent_users_dont_exist: {
    my $user = Socialtext::User->new(username => "this user doesn't exist anywhere");
    ok !defined $user, "users that don't exist return undef";
}

###############################################################################
# users that only have *half* of their data, don't really exist; they're
# "Deleted Users".
#
# This *used to* happen when a user was deleted from the system; it'd purge
# their entry in the "User" (now "user_detail") table, but they'd still have a
# record left in the "UserId" table.
#
# We don't do it that way any more, but need to preserve the behaviour as we
# know that we've got customers out there with data like this in their DBs.
users_without_user_details_are_deleted_users: {
    # create *part* of a new user (the UserId part), and make sure that
    # ST::User thinks that there's now one more of them in the DB.
    my $count_before = Socialtext::User->Count();

    my $user_id = Socialtext::UserId->create(
        user_id             => Socialtext::UserId->NewUserId(),
        driver_key          => 'Default',
        driver_username     => 'Nemo',
        driver_unique_id    => 999999999,
    );
    isa_ok $user_id, 'Socialtext::UserId', 'newly created (partial) user';

    my $count_after = Socialtext::User->Count();
    is $count_after, $count_before+1, '... and ST::User thinks we have one more user';

    # go get the user from the DB, and find out what kind of user he is
    my $user = Socialtext::User->new(user_id => $user_id->user_id);
    isa_ok $user, 'Socialtext::User', '... and we can get that user out of the DB';
    is $user->username, 'Nemo', '... ... and it is Nemo';
    isa_ok $user->homunculus, 'Socialtext::User::Deleted', '... ... and he is a Deleted User';
}

###############################################################################
# If the user details fall out of sync with the "UserId" table (such that
# "user_detail.user_id != UserId.driver_unique_id"), make sure that we
# fallback to finding the user details by UserId.driver_username too, *and*
# that the UserId data is updated to reflect the new information in the
# homunculus.
#
# Graham isn't sure where this behaviour/test stemmed from, but presumes that
# at some point we must have had a bad migration or that some user data got
# accidentally deleted/mangled and this feature/behaviour was put in place to
# collect the user data back together.
out_of_sync_user_is_findable: {
    # first, go create the user that we're going to test against.
    my $user = Socialtext::User->create(
        user_id         => Socialtext::UserId->NewUserId(),
        username        => 'baloney user',
        email_address   => 'devnull1@urth.org',
        first_name      => 'Baloney',
        last_name       => 'User',
    );
    isa_ok $user, 'Socialtext::User', 'created test user';
    my $old_user_id = $user->homunculus->user_id();

    # update the user details in the homunculus, purposely getting it out of
    # sync with the data in the UserId table.
    $user->homunculus->update( user_id => Socialtext::UserId->NewUserId() );
    my $new_user_id = $user->homunculus->user_id();
    isnt $old_user_id, $new_user_id, '... user_id in homunculus now out of sync';

    # go find the user again
    my $found_user = Socialtext::User->new(user_id => $old_user_id);
    isa_ok $found_user, 'Socialtext::User', 'found out of sync user';
    is $user->username, $found_user->username, '... found the right user';
    is $found_user->homunculus->user_id(), $new_user_id, '... homunculus show new user_id';

    # make sure the UserId record got updated to reflect the user
    # user_detail.user_id (UserId.driver_unique_id)
    my $found_user_id = Socialtext::UserId->new(
        driver_key          => $user->driver_name,
        driver_unique_id    => $new_user_id,
    );
    isa_ok $found_user_id, 'Socialtext::UserId', '... UserId shows new driver_unique_id';

    # make sure that the *old* UserId record is totally gone
    my $missing_user_id = Socialtext::UserId->new(
        driver_key          => $user->driver_name,
        driver_unique_id    => $old_user_id,
    );
    ok !$missing_user_id, '... old user_id no longer in UserId table';
}
