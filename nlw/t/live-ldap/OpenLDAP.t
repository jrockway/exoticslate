#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use mocked 'Socialtext::Log', qw(:tests);
use Socialtext::LDAP;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 70;

use_ok 'Socialtext::LDAP::OpenLDAP';

###############################################################################
# Instantiation; connecting to a live OpenLDAP server.
instantiation_ok: {
    # bootstrap OpenLDAP and save the config out to YAML
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    my $filename = Socialtext::LDAP->config_filename('Default');
    ok $filename, 'know where to save config file to';

    ok $openldap->save_ldap_config($filename), 'saved LDAP config to YAML';

    # try to connect
    my $ldap = Socialtext::LDAP->new();
    isa_ok $ldap, 'Socialtext::LDAP::OpenLDAP', 'connected to OpenLDAP server';
}

###############################################################################
# Instantiation; failure to bind due to invalid credentials.
instantiation_invalid_credentials: {
    # bootstrap OpenLDAP and save the config out to YAML
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    my $filename = Socialtext::LDAP->config_filename('Default');
    ok $filename, 'know where to save config file to';

    ok $openldap->save_ldap_config($filename), 'saved LDAP config to YAML';

    # set incorrect password into config
    my $config = Socialtext::LDAP::Config->load($filename);
    isa_ok $config, 'Socialtext::LDAP::Config', 'loaded config from YAML';
    $config->bind_password( 'this-is-the-wrong-password' );
    $config->save($filename);

    # try to connect; should fail
    clear_log();
    my $ldap = Socialtext::LDAP->new();
    ok !$ldap, 'failed to connect to LDAP server';
    logged_like 'error', qr/unable to bind/, '... failed to bind';
}

###############################################################################
# Instantiation; requires auth (anonymous bind not allowed)
instantiation_requires_auth: {
    # bootstrap OpenLDAP and save the config out to YAML
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new(requires_auth=>1);
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    my $filename = Socialtext::LDAP->config_filename('Default');
    ok $filename, 'know where to save config file to';

    ok $openldap->save_ldap_config($filename), 'saved LDAP config to YAML';

    # connect, to make sure that it works fine with required auth
    my $ldap = Socialtext::LDAP->new();
    isa_ok $ldap, 'Socialtext::LDAP::OpenLDAP', 'connect fine with auth';
    $ldap = undef;

    # remove user/pass from config, so we do an anonymous bind.
    my $config = Socialtext::LDAP::Config->load($filename);
    isa_ok $config, 'Socialtext::LDAP::Config', 'loaded config from YAML';
    $config->bind_user( undef );
    $config->bind_password( undef );
    $config->save($filename);

    # connect w/anonymous bind; should fail
    clear_log();
    $ldap = Socialtext::LDAP->new();
    ok !$ldap, 'anonymous bind fails';
    logged_like 'error', qr/unable to bind/, '... failed to bind';
}

###############################################################################
# Authentication failure.
authentication_failure: {
    # bootstrap OpenLDAP and save the config out to YAML
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    my $filename = Socialtext::LDAP->config_filename('Default');
    ok $filename, 'know where to save config file to';

    ok $openldap->save_ldap_config($filename), 'saved LDAP config to YAML';

    # attempt to authenticate, using wrong password
    clear_log();
    my $user = $openldap->root_dn();
    my $pass = 'this-is-the-wrong-password';
    ok !Socialtext::LDAP->authenticate($user,$pass), 'authentication failed';
    logged_like 'info', qr/authentication failed/, '... auth failed';
}

###############################################################################
# Authentication success.
authentication_ok: {
    # bootstrap OpenLDAP and save the config out to YAML
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    my $filename = Socialtext::LDAP->config_filename('Default');
    ok $filename, 'know where to save config file to';

    ok $openldap->save_ldap_config($filename), 'saved LDAP config to YAML';

    # attempt to authenticate, using wrong password
    my $user = $openldap->root_dn();
    my $pass = $openldap->root_pw();
    ok( Socialtext::LDAP->authenticate($user,$pass), 'authentication ok' );
}

###############################################################################
# Search, no results.
search_no_results: {
    # bootstrap OpenLDAP and save the config out to YAML
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    my $filename = Socialtext::LDAP->config_filename('Default');
    ok $filename, 'know where to save config file to';

    ok $openldap->save_ldap_config($filename), 'saved LDAP config to YAML';

    # populate OpenLDAP with some data
    ok $openldap->add('t/test-data/ldap/base_dn.ldif'), 'added data; base_dn';
    ok $openldap->add('t/test-data/ldap/people.ldif'), 'added data; people';

    # search should execute ok, but have no results
    my $ldap = Socialtext::LDAP->new();
    isa_ok $ldap, 'Socialtext::LDAP::OpenLDAP', 'connected to OpenLDAP';

    my $mesg = $ldap->search(
        base    => $openldap->base_dn(),
        filter  => '(cn=This User Does Not Exist)',
        );
    ok !$mesg->code(), 'search executed successfully';
    is $mesg->count(), 0, 'search returned zero results';
}

###############################################################################
# Search, with results.
search_with_results: {
    # bootstrap OpenLDAP and save the config out to YAML
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    my $filename = Socialtext::LDAP->config_filename('Default');
    ok $filename, 'know where to save config file to';

    ok $openldap->save_ldap_config($filename), 'saved LDAP config to YAML';

    # populate OpenLDAP with some data
    ok $openldap->add('t/test-data/ldap/base_dn.ldif'), 'added data; base_dn';
    ok $openldap->add('t/test-data/ldap/people.ldif'), 'added data; people';

    # searches should execute ok, and contain correct number of results
    my $ldap = Socialtext::LDAP->new();
    isa_ok $ldap, 'Socialtext::LDAP::OpenLDAP', 'connected to OpenLDAP';

    my $mesg = $ldap->search(
        base    => $openldap->base_dn(),
        filter  => '(mail=*)',
        );
    ok !$mesg->code(), 'search executed successfully';
    is $mesg->count(), 3, 'search returned three results';

    $mesg = $ldap->search(
        base    => $openldap->base_dn(),
        filter  => '(telephoneNumber=*)',
        );
    ok !$mesg->code(), 'search executed successfully';
    is $mesg->count(), 1, 'search returned one result';
}

###############################################################################
# Search with -NO- global "filter"; should return both "users" and "contacts"
search_without_filter_gets_users_and_contacts: {
    # bootstrap OpenLDAP and save the config out to YAML
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    my $filename = Socialtext::LDAP->config_filename('Default');
    ok $filename, 'know where to save config file to';

    ok $openldap->save_ldap_config($filename), 'saved LDAP config to YAML';

    # populate OpenLDAP with some data
    ok $openldap->add('t/test-data/ldap/base_dn.ldif'), 'added data; base_dn';
    ok $openldap->add('t/test-data/ldap/people.ldif'), 'added data; people';
    ok $openldap->add('t/test-data/ldap/contacts.ldif'), 'added data; contacts';

    # check to make sure that LDAP config has -NO- filter in it
    my $ldap = Socialtext::LDAP->new();
    isa_ok $ldap, 'Socialtext::LDAP::OpenLDAP', 'connected to OpenLDAP';
    ok !$ldap->config->filter(), 'no global "filter" defined in config';

    # unfiltered results should get multiple results
    my $mesg = $ldap->search(
        base    => $openldap->base_dn(),
        filter  => '(cn=John Doe)',
        attrs   => ['objectClass'],
        );
    ok !$mesg->code(), 'search executed successfully';
    is $mesg->count(), 2, 'search returned two results';

    my @entries = $mesg->entries();
    my $inetOrgPerson        = grep { $_->get_value('objectClass') eq 'inetOrgPerson'        } @entries;
    my $organizationalPerson = grep { $_->get_value('objectClass') eq 'organizationalPerson' } @entries;
    ok $inetOrgPerson, 'one result was an inetOrgPerson';
    ok $organizationalPerson, 'one result was an organizationalPerson';
}

###############################################################################
# Search with global "filter"; restricts us to just "users"
search_with_filter_gets_users_only: {
    # bootstrap OpenLDAP and save the config out to YAML
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    my $filename = Socialtext::LDAP->config_filename('Default');
    ok $filename, 'know where to save config file to';

    ok $openldap->save_ldap_config($filename), 'saved LDAP config to YAML';

    # populate OpenLDAP with some data
    ok $openldap->add('t/test-data/ldap/base_dn.ldif'), 'added data; base_dn';
    ok $openldap->add('t/test-data/ldap/people.ldif'), 'added data; people';
    ok $openldap->add('t/test-data/ldap/contacts.ldif'), 'added data; contacts';

    # add a filter to our LDAP config
    my $config = Socialtext::LDAP::Config->load($filename);
    isa_ok $config, 'Socialtext::LDAP::Config', 'loaded LDAP config from YAML';
    $config->filter( '(objectClass=inetOrgPerson)' );
    ok $config->save($filename), 'saved updated LDAP config back out to YAML';

    # filtered results should have single result (an inetOrgPerson)
    my $ldap = Socialtext::LDAP->new();
    isa_ok $ldap, 'Socialtext::LDAP::OpenLDAP', 'connected to OpenLDAP';
    my $mesg = $ldap->search(
        base    => $openldap->base_dn(),
        filter  => '(cn=John Doe)',
        attrs   => ['objectClass'],
        );
    ok !$mesg->code(), 'search executed successfully';
    is $mesg->count(), 1, 'search returned one result';

    my $user = $mesg->shift_entry();
    ok $user, 'got result record';
    is $user->get_value('objectClass'), 'inetOrgPerson', 'which is an inetOrgPerson';
}
