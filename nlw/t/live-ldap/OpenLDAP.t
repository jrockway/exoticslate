#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use mocked 'Socialtext::Log', qw(:tests);
use Socialtext::LDAP;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 58;

use_ok 'Socialtext::LDAP::OpenLDAP';

###############################################################################
# Instantiation; connecting to a live OpenLDAP server.
instantiation_ok: {
    # bootstrap OpenLDAP
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    # save LDAP config to YAML
    my $config = $openldap->ldap_config();
    my $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'saved LDAP config to YAML';

    # try to connect
    my $ldap = Socialtext::LDAP->new();
    isa_ok $ldap, 'Socialtext::LDAP::OpenLDAP', 'connected to OpenLDAP server';
}

###############################################################################
# Instantiation; failure to bind due to invalid credentials.
instantiation_invalid_credentials: {
    # bootstrap OpenLDAP
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    # set incorrect password into config, and save LDAP config to YAML
    my $config = $openldap->ldap_config();
    $config->bind_password( 'this-is-the-wrong-password' );
    my $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'saved updated LDAP config back out to YAML';

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

    # save LDAP config to YAML
    my $config = $openldap->ldap_config();
    my $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'saved LDAP config to YAML';

    # connect, to make sure that it works fine with required auth
    my $ldap = Socialtext::LDAP->new();
    isa_ok $ldap, 'Socialtext::LDAP::OpenLDAP', 'connect fine with auth';
    $ldap = undef;

    # remove user/pass from config, so we do an anonymous bind.
    $config->bind_user( undef );
    $config->bind_password( undef );
    $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'saved updated LDAP config back out to YAML';

    # connect w/anonymous bind; should fail
    clear_log();
    $ldap = Socialtext::LDAP->new();
    ok !$ldap, 'anonymous bind fails';
    logged_like 'error', qr/unable to bind/, '... failed to bind';
}

###############################################################################
# Authentication failure.
authentication_failure: {
    # bootstrap OpenLDAP
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    # save LDAP config to YAML
    my $config = $openldap->ldap_config();
    my $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'saved LDAP config to YAML';

    # attempt to authenticate, using wrong password
    clear_log();
    my %opts = (
        user_id     => $openldap->root_dn(),
        password    => 'this-is-the-wrong-password',
    );
    my $authok = Socialtext::LDAP->authenticate(%opts);
    ok !$authok, 'authentication failed';
    logged_like 'info', qr/authentication failed/, '... auth failed';
}

###############################################################################
# Authentication success.
authentication_ok: {
    # bootstrap OpenLDAP
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    # save LDAP config to YAML
    my $config = $openldap->ldap_config();
    my $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'saved LDAP config to YAML';

    # attempt to authenticate, using a known username/password
    my %opts = (
        user_id     => $openldap->root_dn(),
        password    => $openldap->root_pw(),
    );
    my $authok = Socialtext::LDAP->authenticate(%opts);
    ok $authok, 'authentication ok';
}

###############################################################################
# Search, no results.
search_no_results: {
    # bootstrap OpenLDAP
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    # save LDAP config to YAML
    my $config = $openldap->ldap_config();
    my $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'saved LDAP config to YAML';

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
    # bootstrap OpenLDAP
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    # save LDAP config to YAML
    my $config = $openldap->ldap_config();
    my $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'saved LDAP config to YAML';

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
    # bootstrap OpenLDAP
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    # save LDAP config to YAML
    my $config = $openldap->ldap_config();
    my $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'saved LDAP config to YAML';

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
    # bootstrap OpenLDAP
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    # set filter into our config, and save LDAP config to YAML
    my $config = $openldap->ldap_config();
    $config->filter( '(objectClass=inetOrgPerson)' );
    my $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'saved LDAP config to YAML';

    # populate OpenLDAP with some data
    ok $openldap->add('t/test-data/ldap/base_dn.ldif'), 'added data; base_dn';
    ok $openldap->add('t/test-data/ldap/people.ldif'), 'added data; people';
    ok $openldap->add('t/test-data/ldap/contacts.ldif'), 'added data; contacts';

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
