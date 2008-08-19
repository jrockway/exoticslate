#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 90;
use Socialtext::User;

fixtures( 'rdbms_clean', 'destructive' );
use_ok 'Socialtext::User::Default::Factory';

###############################################################################
# Factory instantiation with no parameters.
instantiation_no_parameters: {
    my $factory = Socialtext::User::Default::Factory->new();
    isa_ok $factory, 'Socialtext::User::Default::Factory';
}

###############################################################################
# Factory instantiation with parameters (which are actually just ignored)
instantiation_named_factory: {
    my $factory = Socialtext::User::Default::Factory->new('Ignored Parameter');
    isa_ok $factory, 'Socialtext::User::Default::Factory';
}

###############################################################################
# Count number of configured users; initial set should always have two users.
count_initial_users: {
    my $factory = Socialtext::User::Default::Factory->new();
    isa_ok $factory, 'Socialtext::User::Default::Factory';

    is $factory->Count(), 2, 'expected to find two initial users';
}

###############################################################################
# Verify initial users that we ALWAYS have available
verify_initial_users: {
    my $factory = Socialtext::User::Default::Factory->new();
    isa_ok $factory, 'Socialtext::User::Default::Factory';

    my $user_system = $factory->GetUser(username => 'system-user');
    isa_ok $user_system, 'Socialtext::User::Default', '... system user exists';
    is $user_system->username, 'system-user', '... ... and its the right user';

    my $user_guest  = $factory->GetUser(username => 'guest');
    isa_ok $user_guest, 'Socialtext::User::Default', '... guest user exists';
    is $user_guest->username, 'guest', '... ... and its the right user';
}

###############################################################################
# Create a new user record
create_new_user: {
    my $factory = Socialtext::User::Default::Factory->new();
    isa_ok $factory, 'Socialtext::User::Default::Factory';

    # hold onto the current user count; we'll check it after creating the new
    # user.
    my $orig_count = $factory->Count();

    # create the new user record and verify the results
    my %opts = (
        username        => 'devnull9@socialtext.net',
        email_address   => 'devnull9@socialtext.net',
        password        => 'password',
    );
    my $user = $factory->create( %opts );
    isa_ok $user, 'Socialtext::User::Default', 'created new user';
    is $user->username, $opts{username}, '... username matches';
    is $user->email_address, $opts{email_address}, '... email_address matches';
    isnt $user->password, $opts{password}, '... password appears encrypted';
    ok $user->password_is_correct('password'), '... encrypted password is correct';

    # make sure user got added to DB correctly
    is $factory->Count(), $orig_count+1, '... user count incremented';
}

###############################################################################
# Create a new user record with an ALREADY ENCRYPTED password
create_new_user_unencrypted_password: {
    my $factory = Socialtext::User::Default::Factory->new();
    isa_ok $factory, 'Socialtext::User::Default::Factory';

    # hold onto the current user count; we'll check it after creating the new
    # user
    my $orig_count = $factory->Count();

    # create the new user record and verify the results
    my %opts = (
        username        => 'devnull8@socialtext.net',
        email_address   => 'devnull8@socialtext.net',
        password        => Socialtext::User::Default->_crypt('password', 'random-salt'),
        no_crypt        => 1,
    );
    my $user = $factory->create( %opts );
    isa_ok $user, 'Socialtext::User::Default', 'created new user';
    is $user->username, $opts{username}, '... username matches';
    is $user->email_address, $opts{email_address}, '... email_address matches';
    is $user->password, $opts{password}, '... password NOT encrypted';
    ok $user->password_is_correct('password'), '... UN-encrypted password is correct';

    # make sure user got added to DB correctly
    is $factory->Count(), $orig_count+1, '... user count incremented';
}

###############################################################################
# Creating a new user does perform data cleanup/validation.
creating_new_user_does_data_cleanup: {
    my $factory = Socialtext::User::Default::Factory->new();
    isa_ok $factory, 'Socialtext::User::Default::Factory';

    my %opts = (
        username        => 'DEVNULL7@SOCIALTEXT.NET',
        email_address   => '   DEVNULL7@socialtext.net   ',
        password        => 'password',
    );
    my $user = $factory->create( %opts );
    isa_ok $user, 'Socialtext::User::Default', 'created new user';

    is $user->username(), 'devnull7@socialtext.net', '... username is lower-case';
    is $user->email_address(), 'devnull7@socialtext.net', '... email_address is lower_case and cleaned up';
}

###############################################################################
# Delete a user record (directly against factory)
delete_user_record_via_factory: {
    my $factory = Socialtext::User::Default::Factory->new();
    isa_ok $factory, 'Socialtext::User::Default::Factory';

    # hold onto the current user count; we'll check it later.
    my $orig_count = $factory->Count();

    # create a new user record
    my %opts = (
        username        => 'devnull6@socialtext.net',
        email_address   => 'devnull6@socialtext.net',
        password        => 'password',
    );
    my $user = $factory->create( %opts );
    isa_ok $user, 'Socialtext::User::Default', 'created new user';
    is $factory->Count(), $orig_count+1, 'user count incremented';

    # delete the user record
    ok $factory->delete($user), '... deleted user record (via factory)';
    is $factory->Count(), $orig_count, '... user count decremented';
}

###############################################################################
# Delete a user record (using helper method in ST::User::Default)
delete_user_record_via_user: {
    my $factory = Socialtext::User::Default::Factory->new();
    isa_ok $factory, 'Socialtext::User::Default::Factory';

    # hold onto the current user count; we'll check it later.
    my $orig_count = $factory->Count();

    # create a new user record
    my %opts = (
        username        => 'devnull6@socialtext.net',
        email_address   => 'devnull6@socialtext.net',
        password        => 'password',
    );
    my $user = $factory->create( %opts );
    isa_ok $user, 'Socialtext::User::Default', 'created new user';
    is $factory->Count(), $orig_count+1, 'user count incremented';

    # delete the user record
    ok $user->delete(), '... deleted user record (via user record)';
    is $factory->Count(), $orig_count, '... user count decremented';
}

###############################################################################
# Verify list of valid search terms when retrieving a user record
get_user_valid_search_terms: {
    my $factory = Socialtext::User::Default::Factory->new();
    isa_ok $factory, 'Socialtext::User::Default::Factory';

    # create user record to search for
    my %opts = (
        username        => 'devnull5@socialtext.net',
        email_address   => 'devnull5@socialtext.net',
        password        => Socialtext::User::Default->_crypt('password', 'random-salt'),
        no_crypt        => 1,
    );
    my $user = $factory->create( %opts );
    isa_ok $user, 'Socialtext::User::Default', 'created new user';

    # "username" is a valid search term
    my $found = $factory->GetUser(username => $opts{username});
    isa_ok $found, 'Socialtext::User::Default', '... username; valid search term';

    # "user_id" is a valid search term
    $found = $factory->GetUser(user_id => $user->user_id());
    isa_ok $found, 'Socialtext::User::Default', '... user_id; valid search term';

    # "email_address" is a valid search term
    $found = $factory->GetUser(email_address => $opts{email_address});
    isa_ok $found, 'Socialtext::User::Default', '... email_address; valid search term';

    # "password" isn't a valid search term
    $found = $factory->GetUser(password => $opts{password});
    ok !defined $found, '... password: INVALID search term';

    # cleanup
    ok $factory->delete($user), '... cleanup';
}

###############################################################################
# Verify that retrieving a user record with blank/undefined value returns
# empty handed.
get_user_blank_value: {
    my $factory = Socialtext::User::Default::Factory->new();
    isa_ok $factory, 'Socialtext::User::Default::Factory';

    my $user = $factory->GetUser(username => undef);
    ok !defined $user, 'get user w/undef value returns empty-handed';
}

###############################################################################
# Verify that retrieving an unknown user returns empty handed.
get_user_unknown_user: {
    my $factory = Socialtext::User::Default::Factory->new();
    isa_ok $factory, 'Socialtext::User::Default::Factory';

    my $user = $factory->GetUser(username => 'missing-user@socialtext.net');
    ok !defined $user, 'get unknown user returns empty-handed';
}

###############################################################################
# User retrieval via "username"
get_user_via_username: {
    my $factory = Socialtext::User::Default::Factory->new();
    isa_ok $factory, 'Socialtext::User::Default::Factory';

    # create a user to go searching for
    my %opts = (
        username        => 'devnull5@socialtext.net',
        email_address   => 'devnull5@socialtext.net',
        password        => 'password',
    );
    my $user = $factory->create( %opts );
    isa_ok $user, 'Socialtext::User::Default', 'created new user';

    # dig the user out, via "username"
    my $found = $factory->GetUser(username => $opts{username});
    isa_ok $found, 'Socialtext::User::Default', '... found user via "username"';
    is $found->email_address(), $opts{email_address}, '... and its the right user';

    # cleanup
    ok $factory->delete($user), '... cleanup';
}

###############################################################################
# User retrieval via "username" is case IN-sensitive
get_user_via_username_is_case_insensitive: {
    my $factory = Socialtext::User::Default::Factory->new();
    isa_ok $factory, 'Socialtext::User::Default::Factory';

    # create a user to go searching for
    my %opts = (
        username        => 'devnull5@socialtext.net',
        email_address   => 'devnull5@socialtext.net',
        password        => 'password',
    );
    my $user = $factory->create( %opts );
    isa_ok $user, 'Socialtext::User::Default', 'created new user';

    # dig the user out, via "username"
    my $found = $factory->GetUser(username => uc($opts{username}));
    isa_ok $found, 'Socialtext::User::Default', '... found user via "username" (case IN-sensitively)';
    is $found->email_address(), $opts{email_address}, '... and its the right user';

    # cleanup
    ok $factory->delete($user), '... cleanup';
}

###############################################################################
# User retrieval via "email_address"
get_user_via_email_address: {
    my $factory = Socialtext::User::Default::Factory->new();
    isa_ok $factory, 'Socialtext::User::Default::Factory';

    # create a user to go searching for
    my %opts = (
        username        => 'devnull5@socialtext.net',
        email_address   => 'devnull5@socialtext.net',
        password        => 'password',
    );
    my $user = $factory->create( %opts );
    isa_ok $user, 'Socialtext::User::Default', 'created new user';

    # dig the user out, via "email_address"
    my $found = $factory->GetUser(email_address => $opts{email_address});
    isa_ok $found, 'Socialtext::User::Default', '... found user via "email_address"';
    is $found->username(), $opts{username}, '... and its the right user';

    # cleanup
    ok $factory->delete($user), '... cleanup';
}

###############################################################################
# User retrieval via "user_id"
get_user_via_user_id: {
    my $factory = Socialtext::User::Default::Factory->new();
    isa_ok $factory, 'Socialtext::User::Default::Factory';

    # create a user to go searching for
    my %opts = (
        username        => 'devnull5@socialtext.net',
        email_address   => 'devnull5@socialtext.net',
        password        => 'password',
    );
    my $user = $factory->create( %opts );
    isa_ok $user, 'Socialtext::User::Default', 'created new user';

    # dig the user out, via "user_id"
    my $found = $factory->GetUser(user_id => $user->user_id());
    isa_ok $found, 'Socialtext::User::Default', '... found user via "user_id"';
    is $found->email_address(), $user->email_address(), '... and its the right user';

    # cleanup
    ok $factory->delete($user), '... cleanup';
}

###############################################################################
# User retrieval with non-numeric "user_id" returns empty-handed (as opposed
# to throwing a DB error)
get_user_non_numeric_user_id: {
    my $factory = Socialtext::User::Default::Factory->new();
    isa_ok $factory, 'Socialtext::User::Default::Factory';

    my $found = $factory->GetUser(user_id => 'something non-numeric');
    ok !defined $found, '... returned empty-handed with non-numeric user_id';
}

###############################################################################
# Update user record (directly against factory)
update_user_via_factory: {
    # create a user to update
    my %opts = (
        username        => 'devnull5@socialtext.net',
        email_address   => 'devnull5@socialtext.net',
        password        => 'password',
    );
    my $user = Socialtext::User->create( %opts );
    isa_ok $user, 'Socialtext::User', 'created new user';

    my $homunculus = $user->homunculus;
    isa_ok $homunculus, 'Socialtext::User::Default', '... is a Default homunculus';

    # get a "Default" user factory
    my $factory = Socialtext::User::Default::Factory->new();
    isa_ok $factory, 'Socialtext::User::Default::Factory';

    # update the user record (via the factory)
    my $rc = $factory->update( $homunculus, username => 'bleargh' );
    ok $rc, '... updated users "username" (via factory)';

    # yank user out of DB again and verify update
    my $found = $factory->GetUser( username => 'bleargh' );
    isa_ok $found, 'Socialtext::User::Default', '... found updated user';
    is_deeply $found, $homunculus, '... homunculus matches';

    # cleanup
    ok $factory->delete($homunculus), '... cleanup';
}

###############################################################################
# Update user record (using helper method in ST::User::Default)
update_user_via_user: {
    # create a user to update
    my %opts = (
        username        => 'devnull5@socialtext.net',
        email_address   => 'devnull5@socialtext.net',
        password        => 'password',
    );
    my $user = Socialtext::User->create( %opts );
    isa_ok $user, 'Socialtext::User', 'created new user';

    my $homunculus = $user->homunculus();
    isa_ok $homunculus, 'Socialtext::User::Default', '... is a Default homunculus';

    # get a "Default" user factory
    my $factory = Socialtext::User::Default::Factory->new();
    isa_ok $factory, 'Socialtext::User::Default::Factory';

    # update the user record
    my $rc = $homunculus->update( email_address => 'foo@example.com' );
    ok $rc, '... updated users "email_address" (via user record)';

    # yank user out of DB again and verify update
    my $found = $factory->GetUser( email_address => 'foo@example.com' );
    isa_ok $found, 'Socialtext::User::Default', '... found updated user';
    is_deeply $found, $homunculus, '... homunculus matches';

    # cleanup
    ok $factory->delete($homunculus), '... cleanup';
}

###############################################################################
# Updating a user does perform data cleanup/validation.
updating_user_does_data_cleanup: {
    # create a user to update
    my %opts = (
        username        => 'devnull5@socialtext.net',
        email_address   => 'devnull5@socialtext.net',
        password        => 'password',
    );
    my $user = Socialtext::User->create( %opts );
    isa_ok $user, 'Socialtext::User', 'created new user';

    my $homunculus = $user->homunculus();
    isa_ok $homunculus, 'Socialtext::User::Default', '... is a Default homunculus';

    # update the user record
    my $rc = $homunculus->update( email_address => '  FOO@BAR.COM   ' );
    ok $rc, '... user record updated';
    is $homunculus->email_address(), 'foo@bar.com', '... and cleanup was performed';

    # cleanup
    ok $homunculus->delete(), '... cleanup';
}
