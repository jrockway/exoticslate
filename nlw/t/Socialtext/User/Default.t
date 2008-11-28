#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings FATAL => 'all';
use Test::Socialtext tests => 15;

use_ok 'Socialtext::User::Default';

###############################################################################
### TEST DATA
###############################################################################
my %TEST_USER = (
    user_id         => 123,
    username        => 'test-user',
    email_address   => 'test-user@example.com',
    first_name      => 'First',
    last_name       => 'Last',
    password        => Socialtext::User::Default->_crypt('foobar', 'random-salt'),
    driver_name     => 'Default',
);

###############################################################################
# Instantiation with no parameters; should fail
instantiation_no_parameters: {
    my $user = Socialtext::User::Default->new();
    ok !defined $user, 'instantiation, no parameters';
}

###############################################################################
# Instantiation via data HASH
instantiation_via_hash: {
    my $user = Socialtext::User::Default->new( %TEST_USER );
    isa_ok $user, 'Socialtext::User::Default', 'instantiation via hash';
}

###############################################################################
# Instantiation via data HASH-REF
instantiation_via_hashref: {
    my $user = Socialtext::User::Default->new( { %TEST_USER } );
    isa_ok $user, 'Socialtext::User::Default', 'instantiation via hash-ref';
}

###############################################################################
# User has a valid password.
has_valid_password: {
    my $user = Socialtext::User::Default->new( %TEST_USER );
    isa_ok $user, 'Socialtext::User::Default';
    ok $user->has_valid_password(), 'has valid password';
}

###############################################################################
# User DOESN'T have a valid password.
does_not_have_valid_password: {
    my $user = Socialtext::User::Default->new( %TEST_USER, password => '*none*' );
    isa_ok $user, 'Socialtext::User::Default';
    ok !$user->has_valid_password(), 'does not have valid password';
}

###############################################################################
# Can we access the user's password?
can_access_password: {
    my $user = Socialtext::User::Default->new( %TEST_USER );
    isa_ok $user, 'Socialtext::User::Default';
    is $user->password(), $TEST_USER{password}, 'can access users password';
}

###############################################################################
# Verify user's password?
verify_users_password: {
    my $user = Socialtext::User::Default->new( %TEST_USER );
    isa_ok $user, 'Socialtext::User::Default';
    ok  $user->password_is_correct('foobar'),  'verify password; success';
    ok !$user->password_is_correct('bleargh'), 'verify password; failure';

}

###############################################################################
# Convert the user record back into a hash.
to_hash: {
    my $user = Socialtext::User::Default->new( %TEST_USER );
    isa_ok $user, 'Socialtext::User::Default';

    my $hashref = $user->to_hash();
    my @fields  = qw(user_id username email_address first_name last_name password);
    my %expected = map { $_=>$TEST_USER{$_} } @fields;
    is_deeply $hashref, \%expected, 'converted user to hash, with right structure';
}
