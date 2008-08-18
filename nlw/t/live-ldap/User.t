#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Socialtext::AppConfig;
use Socialtext::LDAP;
use Socialtext::User;
use Socialtext::User::Default::Factory;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 27;

# FIXTURE: db
#
# Need to have Pg running, but it doesn't have to contain any data.
fixtures( 'db' );

###############################################################################
### TEST DATA
###
### Create a test user in the Default user store (Pg) that conflicts with one
### of the users in our LDAP test data.
###############################################################################
my $default_user = Socialtext::User::Default::Factory->new->create(
    username        => 'John Doe',
    email_address   => 'john.doe@example.com',
    password        => 'pg-password',
    );
isa_ok $default_user, 'Socialtext::User::Default', 'added Pg data; people';

###############################################################################
# Instantiate user from LDAP, even when one exists in PostgreSQL.
# - want to make sure that if LDAP is the first declared factory, that it
#   picks up the user from here first
instantiate_user_from_ldap_even_when_exists_in_postgresql: {
    # bootstrap OpenLDAP
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    # save LDAP config to YAML
    my $config = $openldap->ldap_config();
    my $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'saved LDAP config to YAML';

    # populate OpenLDAP with users
    ok $openldap->add('t/test-data/ldap/base_dn.ldif'), 'added data; base_dn';
    ok $openldap->add('t/test-data/ldap/people.ldif'), 'added data; people';

    # set ordering of "user_factories"; LDAP first, Pg second
    my $appconfig = Socialtext::AppConfig->new();
    $appconfig->set( 'user_factories' => 'LDAP;Default' );
    $appconfig->write();
    is $appconfig->user_factories(), 'LDAP;Default', 'user_factories set';

    # instantiate user; should get from LDAP, not Pg
    my $user = Socialtext::User->new(
        username => 'John Doe',
        );
    isa_ok $user, 'Socialtext::User', 'instantiated user';
    is $user->driver_name(), 'LDAP', '... with LDAP driver';
    isa_ok $user->homunculus(), 'Socialtext::User::LDAP', '... and LDAP homunculus';
}

###############################################################################
# Instantiate user from PostgreSQL, when only contact exists in LDAP
# - want to make sure that if LDAP contains a non-user entry that we pick up
#   the user from PostgreSQL (even if LDAP is the first factory)
instantiate_user_from_postgresql_when_only_contact_in_ldap: {
    # bootstrap OpenLDAP
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    # set global filter into config, and save LDAP config to YAML
    my $config = $openldap->ldap_config();
    my $filter = '(objectClass=inetOrgPerson)';
    $config->filter($filter);
    is $config->filter(), $filter, '... set global LDAP filter';
    my $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'saved LDAP config to YAML';

    # populate OpenLDAP with contacts (-NOT- users)
    ok $openldap->add('t/test-data/ldap/base_dn.ldif'), 'added data; base_dn';
    ok $openldap->add('t/test-data/ldap/contacts.ldif'), 'added data; contacts';

    # set ordering of "user_factories"; LDAP first, Pg second
    my $appconfig = Socialtext::AppConfig->new();
    $appconfig->set( 'user_factories' => 'LDAP;Default' );
    $appconfig->write();
    is $appconfig->user_factories(), 'LDAP;Default', 'user_factories set';

    # instantiate user; should get from Pg, not LDAP
    my $user = Socialtext::User->new(
        username => 'John Doe',
        );
    isa_ok $user, 'Socialtext::User', 'instantiated user';
    is $user->driver_name(), 'Default', '... with Default driver';
    isa_ok $user->homunculus(), 'Socialtext::User::Default', '... and Default homunculus';
}

###############################################################################
# LDAP users *NEVER* have a password field in the homunculus; we *DON'T* grab
# that info from the LDAP store.
ldap_users_have_no_password: {
    # bootstrap OpenLDAP
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    # save LDAP config to YAML
    my $config = $openldap->ldap_config();
    my $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'saved LDAP config to YAML';

    # populate OpenLDAP with users
    ok $openldap->add('t/test-data/ldap/base_dn.ldif'), 'added data; base_dn';
    ok $openldap->add('t/test-data/ldap/people.ldif'), 'added data; people';

    # set ordering of "user_factories"; LDAP first, Pg second
    my $appconfig = Socialtext::AppConfig->new();
    $appconfig->set( 'user_factories' => 'LDAP;Default' );
    $appconfig->write();
    is $appconfig->user_factories(), 'LDAP;Default', 'user_factories set';

    # instantiate LDAP user.
    my $user = Socialtext::User->new(
        username => 'John Doe',
        );
    isa_ok $user, 'Socialtext::User', 'instantiated user';
    is $user->driver_name(), 'LDAP', '... with LDAP driver';

    # make sure the LDAP homunculus has *NO* password attribute
    my $homunculus = $user->homunculus();
    isa_ok $homunculus, 'Socialtext::User::LDAP', '... and LDAP homunculus';
    ok !defined $homunculus->{password}, '... and *NO* password attribute';
}
