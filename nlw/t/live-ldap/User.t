#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Socialtext::AppConfig;
use Socialtext::LDAP;
use Socialtext::User;
use Socialtext::User::Default;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 20;

# FIXTURE: rdbms_clean
#
# Need to have Pg running, but it doesn't have to contain any data.
fixtures( 'rdbms_clean' );

###############################################################################
### TEST DATA
###
### Create a test user in the Default user store (Pg) that conflicts with one
### of the users in our LDAP test data.
###############################################################################
my $default_user = Socialtext::User::Default->create(
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
    # bootstrap OpenLDAP, and save config to YAML
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    my $filename = Socialtext::LDAP->config_filename('Default');
    ok $openldap->save_ldap_config($filename), 'saved LDAP config to YAML';

    # populate OpenLDAP with users
    ok $openldap->add('t/test-data/ldap/base_dn.ldif'), 'added data; base_dn';
    ok $openldap->add('t/test-data/ldap/people.ldif'), 'added data; people';

    # set ordering of "user_factories"; LDAP first, Pg second
    my $appconfig = Socialtext::AppConfig->new();
    $appconfig->set( 'user_factories' => 'LDAP:Default' );
    $appconfig->write();
    is $appconfig->user_factories(), 'LDAP:Default', 'user_factories set';

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
    # bootstrap OpenLDAP, and save config to YAML
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    my $filename = Socialtext::LDAP->config_filename('Default');
    ok $openldap->save_ldap_config($filename), 'saved LDAP config to YAML';

    # add global filter to LDAP YAML for "only users"
    my $ldapcfg = Socialtext::LDAP::Config->load($filename);
    my $filter  = '(objectClass=inetOrgPerson)';
    isa_ok $ldapcfg, 'Socialtext::LDAP::Config', 'loaded LDAP config from YAML';
    $ldapcfg->filter( $filter );
    is $ldapcfg->filter(), $filter, '... set global LDAP filter';
    ok $ldapcfg->save($filename), 'saved updated LDAP config back to YAML';

    # populate OpenLDAP with contacts (-NOT- users)
    ok $openldap->add('t/test-data/ldap/base_dn.ldif'), 'added data; base_dn';
    ok $openldap->add('t/test-data/ldap/contacts.ldif'), 'added data; contacts';

    # set ordering of "user_factories"; LDAP first, Pg second
    my $appconfig = Socialtext::AppConfig->new();
    $appconfig->set( 'user_factories' => 'LDAP:Default' );
    $appconfig->write();
    is $appconfig->user_factories(), 'LDAP:Default', 'user_factories set';

    # instantiate user; should get from Pg, not LDAP
    my $user = Socialtext::User->new(
        username => 'John Doe',
        );
    isa_ok $user, 'Socialtext::User', 'instantiated user';
    is $user->driver_name(), 'Default', '... with Default driver';
    isa_ok $user->homunculus(), 'Socialtext::User::Default', '... and Default homunculus';
}
