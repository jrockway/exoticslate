#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use File::Slurp qw(slurp write_file);
use Socialtext::LDAP::Config;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 34;

###############################################################################
# Authenticate, with LDAP referrals enabled; should succeed
authenticate_with_referrals: {
    diag "TEST: authenticate_with_referrals";
    # set up the OpenLDAP servers
    my ($ldap_src, $ldap_tgt) = setup_ldap_servers_with_referrals();

    # find user record; should succeed
    my $user = Socialtext::User->new( username => 'John Doe' );
    isa_ok $user, 'Socialtext::User', 'found user';
    is $user->driver_name(), 'LDAP', '... in LDAP store';

    # authenticate as the user
    ok $user->password_is_correct('foobar'), '... authen w/correct password';
    ok !$user->password_is_correct('BADPASS'), '... authen w/bad password';
}

###############################################################################
# Authenticate, with LDAP referrals disabled; should fail
authenticate_no_referrals: {
    diag "TEST: authenticate_no_referrals";
    # set up the OpenLDAP servers
    my ($ldap_src, $ldap_tgt) = setup_ldap_servers_with_referrals();

    # update LDAP config, disabling support for LDAP referrals
    my $config = Socialtext::LDAP::Config->load();
    $config->follow_referrals(0);
    my $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'disabled LDAP referrals in LDAP config';

    # find user record; should fail
    my $user = Socialtext::User->new( username => 'John Doe' );
    ok !$user, 'did not find user';
}

###############################################################################
# Search, with LDAP referrals enabled; should return list of users
search_with_referrals: {
    diag "TEST: search_with_referrals";
    # set up the OpenLDAP servers
    my ($ldap_src, $ldap_tgt) = setup_ldap_servers_with_referrals();

    # search for users; should succeed
    my @users = Socialtext::User->Search('john');
    is scalar(@users), 1, 'search returned a single user';

    my $user = shift @users;
    like $user->{driver_name}, qr/^LDAP:/, '... in LDAP store';
}

###############################################################################
# Search, with LDAP referrals disabled; should return empty-handed
search_no_referrals: {
    diag "TEST: search_no_referrals";
    # set up the OpenLDAP servers
    my ($ldap_src, $ldap_tgt) = setup_ldap_servers_with_referrals();

    # update LDAP config, disabling support for LDAP referrals
    my $config = Socialtext::LDAP::Config->load();
    $config->follow_referrals(0);
    my $rc = Socialtext::LDAP::Config->save($config);
    ok $rc, 'disabled LDAP referrals in LDAP config';

    # search for users; should return empty handed
    my @users = Socialtext::User->Search('john');
    ok !@users, 'no users returned from search';
}

###############################################################################
# Set up our OpenLDAP servers, with referral data.
#
# *ALL* queries issued against the configured LDAP user factory will result in
# a referral response.
sub setup_ldap_servers_with_referrals {
    # bootstrap the OpenLDAP referral target
    my $openldap_target = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap_target, 'Test::Socialtext::Bootstrap::OpenLDAP', 'referral target';

    my $target_host = $openldap_target->host();
    my $target_port = $openldap_target->port();

    # bootstrap the OpenLDAP referral source; *ALL* queries issued against
    # this will result in an LDAP referral response
    my $openldap_source = Test::Socialtext::Bootstrap::OpenLDAP->new(
        raw_conf => "referral ldap://${target_host}:${target_port}",
    );
    isa_ok $openldap_source, 'Test::Socialtext::Bootstrap::OpenLDAP', 'referral source';

    # save LDAP config for the referral *source*; the only way we get to the
    # target is through a referral (*not* through our config)
    my $ldap_config = $openldap_source->ldap_config();
    my $rc = Socialtext::LDAP::Config->save($ldap_config);
    ok $rc, 'saved LDAP config to YAML';

    # set user_factories to use the LDAP server first, Default second
    my $ldap_id = $ldap_config->id();
    my $factories = "LDAP:$ldap_id;Default";
    my $appconfig = Socialtext::AppConfig->new();
    $appconfig->set( 'user_factories' => $factories );
    $appconfig->write();
    is $appconfig->user_factories(), $factories, 'user_factories set to LDAP, then Default';

    # populate OpenLDAP servers with data
    ok $openldap_target->add('t/test-data/ldap/base_dn.ldif'), 'added base_dn to referral target';
    ok $openldap_target->add('t/test-data/ldap/people.ldif'),  'added people to referral target';

    # return the OpenLDAP instances back to the caller
    return ($openldap_source, $openldap_target);
}
