#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Socialtext::AppConfig;
use Socialtext::LDAP::Config;
use Socialtext::User;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 18;

###############################################################################
# FIXTURE: db
#
# Need to have Pg running, but it doesn't have to contain any data.
fixtures( 'db' );

###############################################################################
# Attempt to authenticate a user in an OpenLDAP store, by "common name".
authenticate_by_cn: {
    # bootstrap OpenLDAP
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    # populate OpenLDAP
    ok $openldap->add('t/test-data/ldap/base_dn.ldif'), '... added data: base_dn';
    ok $openldap->add('t/test-data/ldap/people.ldif'), '... added data: people';

    # get LDAP config, make sure its set to "username => cn", and save to YAML
    my $config  = $openldap->ldap_config();
    my $attrmap = $config->attr_map();
    $attrmap->{username} = 'cn';
    my $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'saved LDAP config to YAML';

    # set our user_factories to use the LDAP server
    my $appconfig = Socialtext::AppConfig->new();
    $appconfig->set( 'user_factories' => 'LDAP;Default' );
    $appconfig->write();
    is $appconfig->user_factories(), 'LDAP;Default', 'user_factories set to LDAP;Default';

    # instantiate user, by "username", and try to authenticate
    my $user = Socialtext::User->new( username => 'John Doe' );
    isa_ok $user,'Socialtext::User', 'found user';
    is $user->driver_name(), 'LDAP', '... in LDAP store';
    ok $user->password_is_correct('foobar'), '... authen ok with password';
    ok !$user->password_is_correct('BADPASS'), '... authen fails with junk';
}

###############################################################################
# Attempt to authenticate a user in an OpenLDAP store, by "email address".
authenticate_by_mail: {
    # bootstrap OpenLDAP
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    # populate OpenLDAP
    ok $openldap->add('t/test-data/ldap/base_dn.ldif'), '... added data: base_dn';
    ok $openldap->add('t/test-data/ldap/people.ldif'), '... added data: people';

    # get LDAP config, make sure its set to "username => mail", and save to YAML
    my $config  = $openldap->ldap_config();
    my $attrmap = $config->attr_map();
    $attrmap->{username} = 'mail';
    my $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'saved LDAP config to YAML';

    # set our user_factories to use the LDAP server
    my $appconfig = Socialtext::AppConfig->new();
    $appconfig->set( 'user_factories' => 'LDAP;Default' );
    $appconfig->write();
    is $appconfig->user_factories(), 'LDAP;Default', 'user_factories set to LDAP;Default';

    # instantiate user, by "email address", and try to authenticate
    my $user = Socialtext::User->new( username => 'john.doe@example.com' );
    isa_ok $user,'Socialtext::User', 'found user';
    is $user->driver_name(), 'LDAP', '... in LDAP store';
    ok $user->password_is_correct('foobar'), '... authen ok with password';
    ok !$user->password_is_correct('BADPASS'), '... authen fails with junk';
}
