#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Socialtext::AppConfig;
use Socialtext::LDAP;
use Socialtext::LDAP::Config;
use Socialtext::Workspace;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 20;

###############################################################################
# FIXTURE: foobar_no_pages
#
# Need to have the "foobar" workspace available, but don't need any pages in
# it.
###############################################################################
fixtures( 'foobar_no_pages' );

###############################################################################
# What happens if we have a user in an LDAP store and then take away that data
# store entirely?
#
# This is somewhat of a lengthy test; we've got a lot of setup to do to get
# the user store, workspace, and user stuff all created, long before we even
# try removing the store and seeing what happens.
disappearing_ldap_user_store: {
    # bootstrap OpenLDAP
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP', 'bootstrapped OpenLDAP';

    # populate OpenLDAP
    ok $openldap->add('t/test-data/ldap/base_dn.ldif'), '... added data: base_dn';
    ok $openldap->add('t/test-data/ldap/people.ldif'), '... added data: people';

    # save LDAP config, and set up our user_factories to use the LDAP server
    my $openldap_cfg = $openldap->ldap_config();
    my $rc = Socialtext::LDAP::Config->save($openldap_cfg);
    ok $rc, 'saved LDAP config to YAML';

    my $openldap_id    = $openldap_cfg->id();
    my $user_factories = "LDAP:$openldap_id;Default";
    my $appconfig = Socialtext::AppConfig->new();
    $appconfig->set( 'user_factories' => $user_factories );
    $appconfig->write();
    is $appconfig->user_factories(), $user_factories, 'user_factories set to LDAP first, then Default';

    # instantiate the user, and add them to the "foobar" workspace.
    my $ws = Socialtext::Workspace->new( name => 'foobar' );
    isa_ok $ws, 'Socialtext::Workspace', 'found workspace to test with';

    my $user = Socialtext::User->new( username => 'John Doe' );
    isa_ok $user, 'Socialtext::User', 'found user to test with';
    isa_ok $user->homunculus(), 'Socialtext::User::LDAP', '... which came from the LDAP store';

    $ws->add_user( user => $user );
    pass 'added the user to the workspace';

    # enumerate the users in the "foobar" workspace; one of them should be an
    # "LDAP" user.
    my $cursor  = $ws->users_with_roles();
    my @entries = map { $_->[0] } $cursor->all();
    ok @entries, 'got list of users in the workspace';

    my @ldap_users = grep { ref($_->homunculus) eq 'Socialtext::User::LDAP' } @entries;
    is scalar @ldap_users, 1, '... one of which is an LDAP user';
    is $ldap_users[0]->user_id, $user->user_id, '... ... our test user';

    my @deleted_users = grep { ref($_->homunculus) eq 'Socialtext::User::Deleted' } @entries;
    ok !@deleted_users, '... none of which are Deleted users';

    # shut down OpenLDAP, and remove -ALL- of the config that pointed towards
    # its existence.
    undef $openldap;
    unlink Socialtext::LDAP::Config->config_filename();
    ok !-e Socialtext::LDAP::Config->config_filename(), 'removed LDAP configuration file';

    $appconfig->set( 'user_factories' => 'Default' );
    $appconfig->write();
    ok $appconfig->is_default('user_factories'), 'user_factories returned to default value';

    # enumerate the users in the "foobar" workspace again; we should still be
    # able to do so, but now the user from the LDAP store is a "Deleted" user.
    $cursor  = $ws->users_with_roles();
    @entries = map { $_->[0] } $cursor->all();
    ok @entries, 'got list of users in the workspace';

    @ldap_users = grep { ref($_->homunculus) eq 'Socialtext::User::LDAP' } @entries;
    ok !@ldap_users, '... none of which are LDAP users';

    @deleted_users = grep { ref($_->homunculus) eq 'Socialtext::User::Deleted' } @entries;
    is scalar @deleted_users, 1, '... one of which is a Deleted user';
    is $deleted_users[0]->user_id, $user->user_id, '... ... our test user';

    # cleanup; purge the test user from the system.
    ok $user->delete(force=>1), '... removed test user from DB';
}
