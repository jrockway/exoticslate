#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings FATAL => 'all';
use mocked 'Net::LDAP';
use mocked 'Socialtext::Log', qw(:tests);
use Test::Socialtext tests => 18;

# FIXTURE:  ldap_*
#
# These tests have no specific requirement as to whether we're using an
# anonymous or authenticated LDAP connection.
fixtures( 'ldap_anonymous' );
use_ok 'Socialtext::User::LDAP::Factory';

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
# LDAP Auth; fail if no password provided
ldap_auth_password_missing: {
    Net::LDAP->set_mock_behaviour(
        search_results => [ $TEST_USERS[0] ],
        );

    my $factory = Socialtext::User::LDAP::Factory->new();
    isa_ok $factory, 'Socialtext::User::LDAP::Factory';

    my $user = $factory->GetUser(username=>'First Last');
    isa_ok $user, 'Socialtext::User::LDAP';
    ok !$user->password_is_correct(), 'LDAP auth; password missing';
}

###############################################################################
# LDAP Auth; fail if password mismatch
ldap_auth_password_wrong: {
    Net::LDAP->set_mock_behaviour(
        search_results => [ $TEST_USERS[0] ],
        );

    my $factory = Socialtext::User::LDAP::Factory->new();
    isa_ok $factory, 'Socialtext::User::LDAP::Factory';

    my $user = $factory->GetUser(username=>'First Last');
    isa_ok $user, 'Socialtext::User::LDAP';

    # re-mock for Auth... (it'll re-bind)
    Net::LDAP->set_mock_behaviour(
        bind_fail => 1,
        );
    clear_log();

    ok !$user->password_is_correct('bad'), 'LDAP auth; password mismatch';

    # VERIFY auth mocks...
    my $mock = Net::LDAP->mocked_object();
    $mock->called_pos_ok( 1, 'bind' );
    my ($self, $dn, %opts) = $mock->call_args(1);
    is $dn, $user->user_id(), 'LDAP auth; password mismatch used correct DN';
    is $opts{'password'}, 'bad', 'LDAP auth; password mismatch used correct password';

    # VERIFY logs; make sure we failed for the right reason
    logged_like 'info', qr/authentication failed/, '... logged authentication failure';
}

###############################################################################
# LDAP Auth; ok if password match
ldap_auth_password_ok: {
    Net::LDAP->set_mock_behaviour(
        search_results => [ $TEST_USERS[0] ],
        );
    clear_log();

    my $factory = Socialtext::User::LDAP::Factory->new();
    isa_ok $factory, 'Socialtext::User::LDAP::Factory';

    my $user = $factory->GetUser(username=>'First Last');
    isa_ok $user, 'Socialtext::User::LDAP';

    # no need to re-mock for Auth (existing behaviour is ok)
    ok $user->password_is_correct('good'), 'LDAP auth; password match';

    # VERIFY auth mocks...
    my $mock = Net::LDAP->mocked_object();
    $mock->called_pos_ok( 1, 'bind' );
    my ($self, $dn, %opts) = $mock->call_args(1);
    is $dn, $user->user_id(), 'LDAP Auth; password match used correct DN';
    is $opts{'password'}, 'good', 'LDAP auth; password match used correct password';

    # VERIFY logs; should be empty
    is logged_count(), 0, '... logged right number of entries';
}
