#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings FATAL => 'all';
use mocked 'Net::LDAP';
use mocked 'Socialtext::Log', qw(:tests);
use Test::Socialtext tests => 35;

# FIXTURE:  ldap_*
#
# These tests have no specific requirement as to whether we're using an
# anonymous or authenticated LDAP connection.
fixtures( 'ldap_anonymous' );
use_ok 'Socialtext::User::LDAP';

###############################################################################
### TEST DATA
###############################################################################
my @TEST_USERS = (
    { dn            => 'cn=First Last,dc=example,dc=com',
      cn            => 'First Last',
      authPassword  => 'abc123',
      gn            => 'First',
      sn            => 'Last',
      mail          => 'user@example.com',
    },
    { dn            => 'cn=Another User,dc=example,dc=com',
      cn            => 'Another User',
      authPassword  => 'def987',
      gn            => 'Another',
      sn            => 'User',
      mail          => 'user@example.com',
    },
);

###############################################################################
# Instantiation with no parameters; should fail
instantiation_no_parameters: {
    my $user = Socialtext::User::LDAP->new();
    ok !defined $user, 'instantiation, no parameters';
}

###############################################################################
# Instantiation with failed connection; should fail
instantiation_fail_to_ldap_connect: {
    Net::LDAP->set_mock_behaviour(
        connect_fail    => 1,
        );
    clear_log();

    my $user = Socialtext::User::LDAP->new(username=>'First Last');
    ok !defined $user, 'failed to LDAP connect';

    # VERIFY logs; make sure we failed for the right reason
    logged_like 'error', qr/unable to connect/, '... logged connection failure';
}

###############################################################################
# Verify list of valid search terms on instantiation.
instantiation_valid_search_terms: {
    Net::LDAP->set_mock_behaviour(
        search_results => [ $TEST_USERS[0] ],
        );

    # "username" is valid search term
    my $user = Socialtext::User::LDAP->new(username=>'First Last');
    isa_ok $user, 'Socialtext::User::LDAP', 'username; valid instantiation search term';

    # "user_id" is valid search term
    $user = Socialtext::User::LDAP->new(user_id=>'cn=First Last, dc=example,dc=com');
    isa_ok $user, 'Socialtext::User::LDAP', 'user_id; valid instantiation search term';

    # "email_address" is valid search term
    $user = Socialtext::User::LDAP->new(email_address=>'user@example.com');
    isa_ok $user, 'Socialtext::User::LDAP', 'email_address; valid instantiation search term';

    # "first_name" is mapped, but is -NOT- a valid search term
    $user = Socialtext::User::LDAP->new(first_name=>'First');
    ok !defined $user, 'first_name; INVALID instantiation search term';

    # "cn" isn't a valid search term
    $user = Socialtext::User::LDAP->new(cn=>'First Last');
    ok !defined $user, 'cn; INVALID instantiation search term';
}

###############################################################################
# Verify that instantiation with blank/undefined value returns empty handed.
instantiation_blank_values: {
    Net::LDAP->set_mock_behaviour(
        search_results => [ $TEST_USERS[0] ],
        );

    my $user = Socialtext::User::LDAP->new(username=>undef);
    ok !defined $user, 'instantiation w/undef value returns empty-handed';
}

###############################################################################
# Verify that instantiation which fails to find a match in LDAP returns empty
# handed.
instantiation_unknown_user: {
    Net::LDAP->set_mock_behaviour(
        search_results => [],
        );
    clear_log();

    my $user = Socialtext::User::LDAP->new(username=>'First Last');
    ok !defined $user, 'instantiation w/o user in LDAP returns empty-handed';

    # VERIFY logs; make sure we failed for the right reason
    is logged_count(), 1, '... logged right number of entries';
    next_log_like 'debug', qr/unable to find user/, '... logged inability to find user';
}

###############################################################################
# Instantiation with multiple matches should fail; how do we know which one to
# choose?
instantiation_multiple_matches: {
    Net::LDAP->set_mock_behaviour(
        search_results => [ @TEST_USERS ],
        );
    clear_log();

    my $user = Socialtext::User::LDAP->new(email_address=>'user@example.com');
    ok !defined $user, 'instantiation w/multiple matches should fail';

    # VERIFY logs; make sure we failed for the right reason
    is logged_count(), 1, '... logged right number of entries';
    next_log_like 'error', qr/found multiple matches/, '... logged multiple matches';
}

###############################################################################
# Instantiation when unable to bind; returns empty handed
instantiation_bind_failure: {
    Net::LDAP->set_mock_behaviour(
        bind_fail => 1,
        );
    clear_log();

    my $user = Socialtext::User::LDAP->new(username=>'First Last');
    ok !defined $user, 'instantiation w/bind failure';

    # VERIFY logs; make sure we failed for the right reason
    logged_like 'error', qr/unable to bind/, '... logged bind failure';
}

###############################################################################
# Instantiation via "username" is done as a sub-tree search
instantiation_via_username_is_subtree: {
    Net::LDAP->set_mock_behaviour(
        search_results => [ $TEST_USERS[0] ],
        );

    my $user = Socialtext::User::LDAP->new(username=>'First Last');
    isa_ok $user, 'Socialtext::User::LDAP';

    # VERIFY mocks...
    my $mock = Net::LDAP->mocked_object();
    $mock->called_pos_ok( 1, 'bind' );
    $mock->called_pos_ok( 2, 'search' );
    my ($self, %opts) = $mock->call_args(2);
    is $opts{'scope'}, 'sub', 'username search is sub-tree';
}

###############################################################################
# Instantiation via "email_address" is done as a sub-tree search
instantiation_via_email_address_is_subtree: {
    Net::LDAP->set_mock_behaviour(
        search_results => [ $TEST_USERS[0] ],
        );

    my $user = Socialtext::User::LDAP->new(email_address=>'user@example.com');
    isa_ok $user, 'Socialtext::User::LDAP';

    # VERIFY mocks...
    my $mock = Net::LDAP->mocked_object();
    $mock->called_pos_ok( 1, 'bind' );
    $mock->called_pos_ok( 2, 'search' );
    my ($self, %opts) = $mock->call_args(2);
    is $opts{'scope'}, 'sub', 'email_address search is sub-tree';
}

###############################################################################
# Instantiation via "user_id" is optimized to be done as an exact search
instantiation_via_user_id_is_exact: {
    Net::LDAP->set_mock_behaviour(
        search_results => [ $TEST_USERS[0] ],
        );
    my $dn = 'cn=First Last,dc=example,dc=com';

    my $user = Socialtext::User::LDAP->new(user_id=>$dn);
    isa_ok $user, 'Socialtext::User::LDAP';

    # VERIFY mocks...
    my $mock = Net::LDAP->mocked_object();
    $mock->called_pos_ok( 1, 'bind' );
    $mock->called_pos_ok( 2, 'search' );
    my ($self, %opts) = $mock->call_args(2);
    is $opts{'scope'}, 'base', 'user_id search is exact';
    is $opts{'base'}, $dn, 'user_id search base is DN';
}

###############################################################################
# Do LDAP users have valid passwords?  Yes, always
ldap_users_always_have_valid_passwords: {
    Net::LDAP->set_mock_behaviour(
        search_results => [ $TEST_USERS[0] ],
        );

    my $user = Socialtext::User::LDAP->new(username=>'First Last');
    isa_ok $user, 'Socialtext::User::LDAP';
    ok $user->has_valid_password(), 'LDAP users -ALWAYS- have valid passwords';
}

###############################################################################
# LDAP users have restricted/hidden passwords
ldap_users_have_restricted_passwords: {
    Net::LDAP->set_mock_behaviour(
        search_results => [ $TEST_USERS[0] ],
        );

    my $user = Socialtext::User::LDAP->new(username=>'First Last');
    isa_ok $user, 'Socialtext::User::LDAP';
    is $user->password(), '*no-password*', 'LDAP users have restricted passwords';
}
