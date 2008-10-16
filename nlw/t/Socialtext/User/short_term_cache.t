#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings FATAL => 'all';
use Test::More tests => 30;
use mocked 'Socialtext::Log', qw(:tests);
use mocked 'Net::LDAP';
use Test::Socialtext;

fixtures( 'ldap_anonymous' );
use_ok 'Socialtext::User::LDAP::Factory';
use_ok 'Socialtext::User::Default::Factory';

my @TEST_LDAP_USERS = (
    { dn            => 'cn=user,dc=example,dc=com',
      cn            => 'FirstLDAP LastLDAP',
      authPassword  => 'abc123',
      gn            => 'FirstLDAP',
      sn            => 'LastLDAP',
      mail          => 'ldapuser@example.com',
    },
    { dn            => 'cn=user,dc=example,dc=com',
      cn            => 'Another LDAPUser',
      authPassword  => 'def987',
      gn            => 'Another',
      sn            => 'LDAPUser',
      mail          => 'ldapuser@example.com',
    },
);


my $appconfig = Socialtext::AppConfig->new();
$appconfig->set('user_factories', 'LDAP;Default');
$appconfig->write();
is (Socialtext::AppConfig->user_factories(), 'LDAP;Default');

Socialtext::User->create(
    email_address => 'dbuser@example.com',
    username => 'dbuser@example.com',
    first_name => 'DB',
    last_name => 'User',
    password => 'password',
);

sub set_names {
    my ($username, $first, $last) = @_;
    # done in an external process, so that its *not* using any in-memory cache
    my $rc = system("st-admin set-user-names --username $username --first-name $first --last-name $last > /dev/null");
    ok !$rc;
}

verify_not_caching_is_the_default_behaviour: {
    # get a user from LDAP, verify who they are, then mark them as expired (to
    # bypass the long-term cache in the DB).
    Net::LDAP->set_mock_behaviour(
        search_results => [ $TEST_LDAP_USERS[0] ],
    );
    my $user = Socialtext::User->new(email_address => 'ldapuser@example.com');
    ok $user;
    is $user->best_full_name, "FirstLDAP LastLDAP", "original ldap user bfn";
    $user->homunculus->expire();

    # go get the user again, and make sure that we actually went all the way
    # back to LDAP to get them.  By expiring the user we bypassed the long
    # term cache in the DB, and this test shows that we also haven't done any
    # short-term caching in memory.
    Net::LDAP->set_mock_behaviour(
        search_results => [ $TEST_LDAP_USERS[1] ],
    );
    my $user2 = Socialtext::User->new(email_address => 'ldapuser@example.com');
    ok $user2;
    is $user2->best_full_name, "Another LDAPUser", "non-cached ldap user bfn";
    $user2->homunculus->expire();

    # turn off LDAP results (so it doesn't give us a fake mocked response
    # first), and go get a Default user.  Update that user, go get them again,
    # and make sure we got the updated version; we didn't pull them from any
    # short-term cache in memory.
    Net::LDAP->set_mock_behaviour(search_results => []);
    set_names('dbuser@example.com', qw(DB User));

    my $user3 = Socialtext::User->new(username => 'dbuser@example.com');
    ok $user3;
    is $user3->best_full_name, "DB User", "original db user bfn";

    set_names('dbuser@example.com', qw(AnotherDB User));

    my $user4 = Socialtext::User->new(username => 'dbuser@example.com');
    ok $user4;
    is $user4->best_full_name, "AnotherDB User", "non-cached db user bfn";
}

verify_caching_behaviour: {
    # Turn *ON* our short-term in-memory cache.
    no warnings 'once';
    local $Socialtext::User::Cache::Enabled = 1;

    # get a user from LDAP, verify who they are, then mark them as expired (to
    # bypass the long-term cache in the DB)
    Net::LDAP->set_mock_behaviour(
        search_results => [ $TEST_LDAP_USERS[0] ],
    );
    my $user = Socialtext::User->new(email_address => 'ldapuser@example.com');
    ok $user;
    is $user->best_full_name, "FirstLDAP LastLDAP", "original ldap user bfn";
    $user->homunculus->expire();

    # go get the user again, this time expecting that we've used the
    # short-term in memory cache and have *not* gone back to LDAP to get the
    # user again.
    Net::LDAP->set_mock_behaviour(
        search_results => [ $TEST_LDAP_USERS[1] ],
    );
    my $user2 = Socialtext::User->new(email_address => 'ldapuser@example.com');
    ok $user2;
    is $user2->best_full_name, "FirstLDAP LastLDAP", "cached ldap user bfn";
    $user2->homunculus->expire();
    my $ldap_user_id = $user2->user_id;

    # turn off LDAP results (so it doesn't give us a fake mocked response
    # first), and go get a Default user.  Update that user, go get them again,
    # and make sure that we got the *cached* version (and didn't get the
    # updates).
    Net::LDAP->set_mock_behaviour(search_results => []);
    set_names('dbuser@example.com', qw(DB User));

    my $user3 = Socialtext::User->new(username => 'dbuser@example.com');
    ok $user3;
    is $user3->best_full_name, "DB User", "original db user bfn";

    set_names('dbuser@example.com', qw(AwesomeDB User));

    my $user4 = Socialtext::User->new(username => 'dbuser@example.com');
    ok $user4;
    is $user4->best_full_name, "DB User", "cached db user bfn";
    my $db_user_id = $user4->user_id;

    proactive_user_id_caching: {
        my $user5 = Socialtext::User->new(user_id => $ldap_user_id);
        ok $user5;
        is $user5->best_full_name, "FirstLDAP LastLDAP", "proactive cache of the LDAP user";

        my $user6 = Socialtext::User->new(user_id => $db_user_id);
        ok $user6;
        is $user6->best_full_name, "DB User", "proactive cache of the db user";
    }

    lookup_of_non_existant_user: {
        my $user7 = Socialtext::User->new(email_address => 'notyet@example.com');
        ok !$user7, "this user doesn't exist yet";

        # in another process:
        system('st-admin create-user --email notyet@example.com --username notyet@example.com --first-name Iam --last-name Here --password password');
        my $user8 = Socialtext::User->new(email_address => 'notyet@example.com');
        ok $user8;
        is $user8->best_full_name, "Iam Here", "previous cache miss didn't poison the cache";
    }
}

