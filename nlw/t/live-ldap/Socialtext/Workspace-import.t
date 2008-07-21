#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Archive::Tar;
use File::Temp qw();
use Socialtext::AppConfig;
use Socialtext::LDAP;
use Socialtext::LDAP::Config;
use Socialtext::Workspace;
use Socialtext::Workspace;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 29;
use Test::Exception;

###############################################################################
# FIXTURE: foobar
#
# Need to have _some_ workspace available with pages in it that we can export.
###############################################################################
fixtures( 'foobar' );

###############################################################################
# Bug #761; Deleted LDAP user prevents workspace import
#
# Having deleted users at the point of export should not prevent the workspace
# from being able to import again.
#
# Scenario:
#   Customer has LDAP user factories, the "fit hits the shan" and they need to
#   migrate to a new appliance.  The old appliance has *no* connectivity to the
#   LDAP server when the workspaces are exported (so all the users get exported
#   as *deleted users*).
#
#   When workspaces are imported on the new appliance, these deleted users
#   shouldn't prevent the import.  Ideally, the users should be matched up
#   properly against the LDAP user factories on the new appliance, but even if
#   that fails we shouldn't fail catastrophically.
deleted_ldap_user_shouldnt_prevent_workspace_import: {
    # bootstrap OpenLDAP
    my $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP';

    # populate OpenLDAP
    ok $openldap->add('t/test-data/ldap/base_dn.ldif'), '... added data: base_dn';
    ok $openldap->add('t/test-data/ldap/people.ldif'), '... added data: people';

    # save LDAP config, and set up user_factories to use this LDAP server
    my $openldap_cfg = $openldap->ldap_config();
    my $rc = Socialtext::LDAP::Config->save($openldap_cfg);
    ok $rc, 'saved LDAP config to YAML';

    my $openldap_id = $openldap_cfg->id();
    my $user_factories = "LDAP:$openldap_id;Default";
    my $appconfig = Socialtext::AppConfig->new();
    $appconfig->set( 'user_factories' => $user_factories );
    $appconfig->write();
    is $appconfig->user_factories(), $user_factories, 'added LDAP user factory';

    # instantiate a user and add him to the "foobar" workspace
    my $ws = Socialtext::Workspace->new( name => 'foobar' );
    isa_ok $ws, 'Socialtext::Workspace', 'found "foobar" workspace';

    my $user = Socialtext::User->new( username => 'John Doe' );
    isa_ok $user, 'Socialtext::User', 'found user to test with';
    isa_ok $user->homunculus(), 'Socialtext::User::LDAP', '... which came from the LDAP store';

    $ws->add_user(user => $user);
    ok $ws->has_user($user), 'user added to test workspace';

    ###########################################################################
    # simulate loss of connectivity to the LDAP directory
    $openldap = undef;

    ###########################################################################
    # export/delete the workspace+user, and verify that the LDAP user was
    # exported as a "Deleted User".
    my $tmpdir = File::Temp::tempdir(CLEANUP => 1);

    my $tarball = $ws->export_to_tarball(dir => $tmpdir);
    ok -e $tarball, 'workspace exported to tarball';

    $ws->delete();
    $ws = undef;

    my $archive = Archive::Tar->new($tarball, 1);
    isa_ok $archive, 'Archive::Tar', 'exported workspace tarball';
    ok $archive->contains_file('foobar-users.yaml'), '... containing user list';

    my $user_yaml = $archive->get_content('foobar-users.yaml');
    my $users = YAML::Load($user_yaml);
    ok defined $users, '... which could be parsed as valid YAML';

    my ($john_doe) = grep { $_->{username} eq 'John Doe' } @{$users};
    ok defined $john_doe, '... ... and which contained our test user';
    is $john_doe->{email_address}, 'deleted.user@socialtext.com', '... ... ... as a deleted user';

    ###########################################################################
    # re-rig LDAP, just like if we'd been moved to a new appliance

    # bootstrap an entirely new OpenLDAP instance
    $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
    isa_ok $openldap, 'Test::Socialtext::Bootstrap::OpenLDAP';

    # populate OpenLDAP
    ok $openldap->add('t/test-data/ldap/base_dn.ldif'), '... added data: base_dn';
    ok $openldap->add('t/test-data/ldap/people.ldif'), '... added data: people';

    # save LDAP config, and set up user_factories to use the new LDAP server
    $openldap_cfg = $openldap->ldap_config();
    $rc = Socialtext::LDAP::Config->save($openldap_cfg);
    ok $rc, 'saved LDAP config to YAML';

    $openldap_id = $openldap_cfg->id();
    $user_factories = "LDAP:$openldap_id;Default";
    $appconfig = Socialtext::AppConfig->new();
    $appconfig->set( 'user_factories' => $user_factories );
    $appconfig->write();
    is $appconfig->user_factories(), $user_factories, 'added LDAP user factory';

    ###########################################################################
    # Import the workspace

    # shouldn't fail catastrophically
    lives_ok { Socialtext::Workspace->ImportFromTarball(tarball=>$tarball) } 'workspace imported without error';
    $ws = Socialtext::Workspace->new( name => 'foobar' );
    isa_ok $ws, 'Socialtext::Workspace';

    # user should exist in the new workspace, coming from the new LDAP store
    my $imported_user = Socialtext::User->new( username => 'John Doe' );
    isa_ok $imported_user, 'Socialtext::User', 'test user was imported';
    isa_ok $imported_user->homunculus(), 'Socialtext::User::LDAP', '... and found in LDAP store';
    is $imported_user->homunculus->driver_id(), $openldap_id, '... ... from our *new* LDAP store';
    ok $ws->has_user($imported_user), '... and is a member of our test workspace';

    # user data should match that of the original user
    is $imported_user->first_name(), $user->first_name(), '... has correct first name';
    is $imported_user->last_name(), $user->last_name(), '... has correct last name';
    is $imported_user->email_address(), $user->email_address(), '... has correct e-mail address';

    ###########################################################################
    # reset user_factories back to default, so we don't throw other tests out
    $appconfig->set( 'user_factories' => 'Default' );
    $appconfig->write();

    ###########################################################################
    # unlink the tarball now that we're done with it.
    unlink $tarball;
}
