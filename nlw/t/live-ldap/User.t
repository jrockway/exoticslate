#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Socialtext::AppConfig;
use Socialtext::LDAP;
use Socialtext::User;
use Socialtext::User::Default::Factory;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 38;

fixtures( 'rdbms' );

###############################################################################
### TEST DATA
###
### Create a test user in the Default user store (Pg) that conflicts with one
### of the users in our LDAP test data.
###############################################################################
my $default_user_id = Socialtext::UserId->SystemUniqueId();
my $default_user = Socialtext::User::Default::Factory->new->create(
    system_unique_id => $default_user_id,
    username         => 'John Doe',
    email_address    => 'john.doe@example.com',
    password         => 'pg-password',
);
isa_ok $default_user, 'Socialtext::User::Default', 'added Pg data; people';

sub bootstrap_tests {
    my $filter = shift;
    my $populate = shift || 'people';

    # bootstrap OpenLDAP
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    # save LDAP config to YAML
    my $config = $openldap->ldap_config();
    if ($filter) {
        $config->filter($filter);
        is $config->filter, $filter, '... set filter';
    }
    my $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'saved LDAP config to YAML';

    # populate OpenLDAP with users
    ok $openldap->add('t/test-data/ldap/base_dn.ldif'), 'added data; base_dn';
    ok $openldap->add("t/test-data/ldap/$populate.ldif"), 'added data; people';

    # set ordering of "user_factories"; LDAP first, Pg second
    my $appconfig = Socialtext::AppConfig->new();
    $appconfig->set( 'user_factories' => 'LDAP;Default' );
    $appconfig->write();
    is $appconfig->user_factories(), 'LDAP;Default', 'user_factories set';

    return [$openldap, $config, $appconfig];
}

###############################################################################
# Instantiate user from LDAP, even when one exists in PostgreSQL.
# - want to make sure that if LDAP is the first declared factory, that it
#   picks up the user from here first
instantiate_user_from_ldap_even_when_exists_in_postgresql: {
    my $refs = bootstrap_tests();

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
    my $refs = bootstrap_tests('(objectClass=inetOrgPerson)', 'contacts');

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
    my $refs = bootstrap_tests();

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

###############################################################################
# Auto-vivify a LDAP user.
auto_vivify_an_ldap_user: {
    my $refs = bootstrap_tests();

    my $id_before = Socialtext::UserId->SystemUniqueId();

    # instantiate LDAP user.
    my $user = Socialtext::User->new(
        username => 'Jane Smith'
    );
    isa_ok $user, 'Socialtext::User', 'instantiated user';
    is $user->driver_name(), 'LDAP', '... with LDAP driver';
    my $id_after = Socialtext::UserId->SystemUniqueId();

    ok $user->user_id > $id_before, '... has a user_id';
    ok $user->user_id < $id_after, '... not a spontaneous id';

    # make sure the LDAP homunculus has *NO* password attribute
    my $homunculus = $user->homunculus();
    isa_ok $homunculus, 'Socialtext::User::LDAP', '... and LDAP homunculus';
    ok !defined $homunculus->{password}, '... and *NO* password attribute';
}
