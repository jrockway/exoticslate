#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 32;
use Test::Socialtext::User;
use File::Slurp qw(write_file);
use Benchmark qw(timeit timestr);
use Socialtext::SQL qw(sql_execute);

###############################################################################
# FIXTURE: db
#
# Need to have the DB around, but don't care whats in it.
fixtures( 'db' );

###############################################################################
# Sets up OpenLDAP, adds some test data, and adds the OpenLDAP server to our
# list of user factories.
sub set_up_openldap {
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    $openldap->add_ldif('t/test-data/ldap/base_dn.ldif');
    $openldap->add_ldif('t/test-data/ldap/people.ldif');
    return $openldap;
}

###############################################################################
# TEST: if we've got *NO* LDAP users, refresh doesn't choke.
test_no_ldap_users: {
    my $results = `st-refresh-ldap-users --verbose 2>&1`;
    is $?, 0, 'st-refresh-ldap-users ran successfully';
    like $results, qr/found 0 LDAP users/, 'no LDAP users present';
}

###############################################################################
# TEST: have LDAP users, but they're all fresh; not refreshed again.
test_ldap_users_all_fresh: {
    my $ldap = set_up_openldap();

    # add an LDAP user to our DB cache
    my $ldap_user = Socialtext::User->new( email_address => 'john.doe@example.com' );
    isa_ok $ldap_user, 'Socialtext::User', 'LDAP user';

    my $ldap_homey = $ldap_user->homunculus;
    isa_ok $ldap_homey, 'Socialtext::User::LDAP', 'LDAP homunculus';

    # sleep a bit; our granularity on "cached_at" is only to one second, so we
    # need to make sure that we've slept a bit before refreshing the user data
    sleep 2;

    # refresh LDAP users
    my $results = `st-refresh-ldap-users --verbose 2>&1`;
    is $?, 0, 'st-refresh-ldap-users ran successfully';
    like $results, qr/found 1 LDAP users/, 'one LDAP user present';

    # get the refreshed LDAP user record
    my $refreshed_user = Socialtext::User->new( email_address => 'john.doe@example.com' );
    isa_ok $refreshed_user, 'Socialtext::User', 'refreshed LDAP user';

    my $refreshed_homey = $refreshed_user->homunculus;
    isa_ok $refreshed_homey, 'Socialtext::User::LDAP', 'refreshed LDAP homunculus';

    # make sure that we've got different copies of the User object, *but* that
    # they were both cached at the same time (e.g. we didn't just refresh the
    # user).
    isnt $ldap_homey, $refreshed_homey, 'user objects are different';
    is $ldap_homey->cached_at->epoch, $refreshed_homey->cached_at->epoch, 'user was not refreshed; was already fresh';

    # cleanup; don't want to pollute other tests
    Test::Socialtext::User->delete_recklessly($ldap_user);
}

###############################################################################
# TEST: have LDAP users, some of which have never been cached; users that have
# never been cached are refreshed.
#
# We *also* test here to make sure that the first_name/last_name/username are
# refreshed properly.  This is then skipped in subsequent tests (as we've
# already tested for that condition here).
test_refresh_stale_users: {
    my $ldap = set_up_openldap();

    # add an LDAP user to our DB cache
    my $ldap_user = Socialtext::User->new( email_address => 'john.doe@example.com' );
    isa_ok $ldap_user, 'Socialtext::User', 'LDAP user';

    my $ldap_homey = $ldap_user->homunculus;
    isa_ok $ldap_homey, 'Socialtext::User::LDAP', 'LDAP homunculus';

    # update the DB with new info, so we'll be able to verify that the user
    # did in fact get his/her data refreshed from LDAP again.
    sql_execute( qq{
        UPDATE users
           SET first_name='bogus_first',
               last_name='bogus_last',
               driver_username='bogus_username'
         WHERE driver_unique_id=?
        }, $ldap_homey->driver_unique_id );
    my $bogus_user = Socialtext::User->new( email_address => 'john.doe@example.com' );
    is $bogus_user->first_name, 'bogus_first', 'set bogus data to first_name';
    is $bogus_user->last_name, 'bogus_last', 'set bogus data to last_name';
    is $bogus_user->username, 'bogus_username', 'set bogus data to username';

    # expire the user, so that they'll get refreshed
    $ldap_homey->expire();

    # refresh LDAP users
    #
    # granularity on "cached_at" is only to the second, so we'll sleep a bit
    # around the refresh so we can check afterwards that (a) the user was
    # refreshed, and (b) that it was done by st-refresh-ldap-users and not by
    # our re-instantiating the user record.
    my $time_before_refresh = time();
    {
        sleep 2;

        my $results = `st-refresh-ldap-users --verbose 2>&1`;
        is $?, 0, 'st-refresh-ldap-users ran successfully';
        like $results, qr/found 1 LDAP users/, 'one LDAP user present';

        sleep 2;
    }
    my $time_after_refresh = time();

    # get the refreshed LDAP user record
    my $refreshed_user = Socialtext::User->new( email_address => 'john.doe@example.com' );
    isa_ok $refreshed_user, 'Socialtext::User', 'refreshed LDAP user';

    my $refreshed_homey = $refreshed_user->homunculus;
    isa_ok $refreshed_homey, 'Socialtext::User::LDAP', 'refreshed LDAP homunculus';

    # make sure the user *was* refreshed by st-refresh-ldap-users
    my $refreshed_at = $refreshed_homey->cached_at->epoch();
    ok $refreshed_at > $time_before_refresh, 'user was refreshed';
    ok $refreshed_at < $time_after_refresh, '... by st-refresh-ldap-users';

    # make sure that the bogus data we set into the user was over-written by
    # the refresh
    isnt $ldap_homey->first_name, 'bogus_first', '... first_name was refreshed';
    isnt $ldap_homey->last_name, 'bogus_last', '... last_name was refreshed';
    isnt $ldap_homey->username, 'bogus_username', '... username was refreshed';

    # cleanup; don't want to pollute other tests
    Test::Socialtext::User->delete_recklessly($ldap_user);
}

###############################################################################
# TEST: have LDAP users, force the refresh; *all* users are refreshed
# regardless of whether they're fresh/stale.
test_force_refresh: {
    my $ldap = set_up_openldap();

    # add an LDAP user to our DB cache
    my $ldap_user = Socialtext::User->new( email_address => 'john.doe@example.com' );
    isa_ok $ldap_user, 'Socialtext::User', 'LDAP user';

    my $ldap_homey = $ldap_user->homunculus;
    isa_ok $ldap_homey, 'Socialtext::User::LDAP', 'LDAP homunculus';

    # refresh LDAP users
    #
    # granularity on "cached_at" is only to the second, so we'll sleep a bit
    # around the refresh so we can check afterwards that (a) the user was
    # refreshed, and (b) that it was done by st-refresh-ldap-users and not by
    # our re-instantiating the user record.
    my $time_before_refresh = time();
    {
        sleep 2;

        my $results = `st-refresh-ldap-users --verbose --force 2>&1`;
        is $?, 0, 'st-refresh-ldap-users ran successfully';
        like $results, qr/found 1 LDAP users/, 'one LDAP user present';

        sleep 2;
    }
    my $time_after_refresh = time();

    # get the refreshed LDAP user record
    my $refreshed_user = Socialtext::User->new( email_address => 'john.doe@example.com' );
    isa_ok $refreshed_user, 'Socialtext::User', 'refreshed LDAP user';

    my $refreshed_homey = $refreshed_user->homunculus;
    isa_ok $refreshed_homey, 'Socialtext::User::LDAP', 'refreshed LDAP homunculus';

    # make sure the user *was* refreshed by st-refresh-ldap-users
    my $refreshed_at = $refreshed_homey->cached_at->epoch();
    ok $refreshed_at > $time_before_refresh, 'user was refreshed';
    ok $refreshed_at < $time_after_refresh, '... by st-refresh-ldap-users';

    # cleanup; don't want to pollute other tests
    Test::Socialtext::User->delete_recklessly($ldap_user);
}

###############################################################################
# BENCHMARK: how long does it take to refresh ~5000 users?
benchmark_refresh: {
    my $BENCHMARK_USERS = 1000;

    unless ($ENV{NLW_BENCHMARK}) {
        diag "Benchmark tests skipped; set NLW_BENCHMARK=1 to run them";
    }
    else {
        diag "Benchmark tests running; this may take a while...";
        my $t;

        # build up a set of users to use for the benchmark
        my @ldif;
        my @emails;
        foreach my $count (0 .. $BENCHMARK_USERS) {
            my $email = "test-$count\@ken.socialtext.net";
            push @emails, $email;
            push @ldif, <<ENDLDIF;
dn: cn=User $count,dc=example,dc=com
objectClass: inetOrgperson
cn: User $count
gn: User
sn: $count
mail: $email
userPassword: abc123

ENDLDIF
        }

        # add all of the users to OpenLDAP
        my $openldap  = set_up_openldap();
        diag "adding $BENCHMARK_USERS users to OpenLDAP";
        $t = timeit(1, sub {
            my $ldif_file = 'eraseme.ldif';
            write_file( $ldif_file, @ldif );
            $openldap->add_ldif( $ldif_file );
            unlink $ldif_file;
        } );
        diag "... " . timestr($t);

        # add all of the users to our DB.
        #
        # Cheat a bit and re-use our LDAP connection, though, so that we don't
        # have to re-connect for every single one of the test users.
        #
        # NOTE: we re-load the LDAP config so that we're not asking the
        # bootstrapper to *re-generate* the config (it'll create a new id each
        # time we ask it for the config).
        diag "adding $BENCHMARK_USERS users to ST";
        $t = timeit(1, sub {
            my $config  = Socialtext::LDAP::Config->load();
            my $ldap_id = $config->id();
            my $factory = Socialtext::User::LDAP::Factory->new( $ldap_id );
            foreach my $email (@emails) {
                $factory->GetUser( email_address => $email );
            }
        } );
        diag "... " . timestr($t);

        # refresh all of the users
        diag "refreshing $BENCHMARK_USERS users";
        $t = timeit(1, sub {
            `st-refresh-ldap-users --verbose --force 2>&1`;
        } );
        diag "... " . timestr($t);

        # cleanup; remove all our users so that the test harness doesn't spit
        # out gobs of stuff on the screen
        diag "cleaning up $BENCHMARK_USERS users";
        $t = timeit(1, sub {
            foreach my $email (@emails) {
                my $user = Socialtext::User->new( email_address => $email );
                Test::Socialtext::User->delete_recklessly($user);
            }
        } );
        diag "... " . timestr($t);
    }
}
