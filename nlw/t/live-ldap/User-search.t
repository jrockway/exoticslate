#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Socialtext::AppConfig;
use Socialtext::User;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 33;

# FIXTURE: db
#
# Need to have Pg running, but it doesn't have to contain any data.
fixtures( 'db' );

###############################################################################
### TEST DATA
###
### Create a user in the Default data store that we can search for
###############################################################################
create_user: {
    my $user = Socialtext::User->create(
        username        => 'Mike Smith',
        email_address   => 'mike.smith@example.com',
        password        => 'test-password',
        );
    isa_ok $user, 'Socialtext::User', 'created user';
    isa_ok $user->homunculus(), 'Socialtext::User::Default', '... in the Default store';
}

###############################################################################
# User search; no results
search_no_results: {
    # bootstrap OpenLDAP
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    # populate OpenLDAP with users
    ok $openldap->add('t/test-data/ldap/base_dn.ldif'), 'added data; base_dn';
    ok $openldap->add('t/test-data/ldap/people.ldif'), 'added data; people';

    # save LDAP config to YAML
    my $config = $openldap->ldap_config();
    my $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'saved LDAP config to YAML';

    # add our OpenLDAP instance to our "user_factories"
    my $appconfig = Socialtext::AppConfig->new();
    $appconfig->set( 'user_factories' => 'LDAP;Default' );
    $appconfig->write();
    is $appconfig->user_factories(), 'LDAP;Default', 'user_factories set';

    # search for a user that DOESN'T exist in either the DB or in LDAP
    my @users = Socialtext::User->Search('this-user-does-not-exist');
    ok !@users, 'search for non-existent users returns empty handed';
}

###############################################################################
# User search; single result (DB)
search_single_result_from_db: {
    # bootstrap OpenLDAP
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    # populate OpenLDAP with users
    ok $openldap->add('t/test-data/ldap/base_dn.ldif'), 'added data; base_dn';
    ok $openldap->add('t/test-data/ldap/people.ldif'), 'added data; people';

    # save LDAP config to YAML
    my $config = $openldap->ldap_config();
    my $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'saved LDAP config to YAML';

    # add our OpenLDAP instance to our "user_factories"
    my $appconfig = Socialtext::AppConfig->new();
    $appconfig->set( 'user_factories' => 'LDAP;Default' );
    $appconfig->write();
    is $appconfig->user_factories(), 'LDAP;Default', 'user_factories set';

    # search for a user that only exists in our DB store
    my @users = Socialtext::User->Search('mike');
    is scalar(@users), 1, 'search returned a single user';

    my $user = shift @users;
    is $user->{driver_name}, 'Default', '... which comes from Default store';
    is $user->{email_address}, 'mike.smith@example.com', '... and was the user we were expecting';
}

###############################################################################
# User search; single result (LDAP)
search_single_result_from_ldap: {
    # bootstrap OpenLDAP
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    # populate OpenLDAP with users
    ok $openldap->add('t/test-data/ldap/base_dn.ldif'), 'added data; base_dn';
    ok $openldap->add('t/test-data/ldap/people.ldif'), 'added data; people';

    # save LDAP config to YAML
    my $config = $openldap->ldap_config();
    my $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'saved LDAP config to YAML';

    # add our OpenLDAP instance to our "user_factories"
    my $appconfig = Socialtext::AppConfig->new();
    $appconfig->set( 'user_factories' => 'LDAP;Default' );
    $appconfig->write();
    is $appconfig->user_factories(), 'LDAP;Default', 'user_factories set';

    # search for a user that only exists in our LDAP store
    my @users = Socialtext::User->Search('bubba');
    is scalar(@users), 1, 'search returned a single user';

    my $user = shift @users;
    like $user->{driver_name}, qr/^LDAP:/, '... which comes from LDAP store';
    is $user->{email_address}, 'bubba.brain@example.com', '... and was the user we were expecting';
}

###############################################################################
# User search; multiple results
search_multiple_results: {
    # bootstrap OpenLDAP
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    # populate OpenLDAP with users
    ok $openldap->add('t/test-data/ldap/base_dn.ldif'), 'added data; base_dn';
    ok $openldap->add('t/test-data/ldap/people.ldif'), 'added data; people';

    # save LDAP config to YAML
    my $config = $openldap->ldap_config();
    my $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'saved LDAP config to YAML';

    # add our OpenLDAP instance to our "user_factories"
    my $appconfig = Socialtext::AppConfig->new();
    $appconfig->set( 'user_factories' => 'LDAP;Default' );
    $appconfig->write();
    is $appconfig->user_factories(), 'LDAP;Default', 'user_factories set';

    # search for users across both the DB and LDAP stores
    my @users = Socialtext::User->Search('example.com');
    is scalar(@users), 4, 'search returned multiple users';

    my @db_users   = grep { $_->{driver_name} eq 'Default' } @users;
    ok @db_users, '... some of which were from Default store';

    my @ldap_users = grep { $_->{driver_name} =~ /^LDAP:/ } @users;
    ok @ldap_users, '... some of which were from LDAP store';

    my @combined = (@db_users, @ldap_users);
    is scalar(@combined), scalar(@users), '... which accounts for ALL of the users';
}
