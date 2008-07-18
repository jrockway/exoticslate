#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use File::Slurp qw(write_file);
use mocked 'Socialtext::Log', qw(:tests);
use Socialtext::LDAP::Config;
use Socialtext::AppConfig;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Socialtext tests => 10;

###############################################################################
# FIXTURE: rdbms_clean
#
# Need the most minimal of fixtures set up, so that we've got config files
# and test directories created.
fixtures( 'rdbms_clean' );

###############################################################################
# bootstrap a pair of OpenLDAP servers
my $lhs = Test::Socialtext::Bootstrap::OpenLDAP->new();
isa_ok $lhs, 'Test::Socialtext::Bootstrap::OpenLDAP', 'referral LHS';

my $rhs = Test::Socialtext::Bootstrap::OpenLDAP->new();
isa_ok $rhs, 'Test::Socialtext::Bootstrap::OpenLDAP', 'referral RHS';

###############################################################################
# generate some LDIF data that'll put the LDAP servers in an infinite referral
# loop, and add that data to the directories
generate_ldif('t/tmp/recurse-lhs.ldif', $rhs->host(), $rhs->port());
ok $lhs->add('t/tmp/recurse-lhs.ldif'), 'added recursing LDIF to LHS';

generate_ldif('t/tmp/recurse-rhs.ldif', $lhs->host(), $lhs->port());
ok $rhs->add('t/tmp/recurse-rhs.ldif'), 'added recursing LDIF to RHS';

###############################################################################
# save LDAP config for the referral *source*; only need one of them to trigger
# the referral loop
my $ldap_config = $lhs->ldap_config();
my $rc = Socialtext::LDAP::Config->save($ldap_config);
ok $rc, 'saved LDAP config to YAML';

###############################################################################
# set user_factories to use LDAP first, Default second
my $ldap_id   = $ldap_config->id();
my $factories = "LDAP:$ldap_id;Default";
my $appconfig = Socialtext::AppConfig->new();
$appconfig->set( 'user_factories' => $factories );
$appconfig->write();
is $appconfig->user_factories(), $factories, 'user_factories set to LDAP, then Default';

###############################################################################
# TEST: Authenticate, with looping LDAP referrals; should fail
authenticate_looping_referrals: {
    diag "TEST: authenticate_looping_referrals";
    clear_log();

    # find user; should fail
    my $user = Socialtext::User->new( username => 'John Doe' );
    ok !$user, 'did not find user';

    # make sure we failed because of looping referrals
    logged_like 'warning', qr/max referral depth/, '... due to max referral depth being reached';
}

###############################################################################
# TEST: Search, with looping LDAP referrals; should fail
search_looping_referrals: {
    diag "TEST: search_looping_referrals";
    clear_log();

    # search for users; should return empty handed
    my @users = Socialtext::User->Search('john');
    ok !@users, 'no users returned from search';

    # make sure we failed because of looping referrals
    logged_like 'warning', qr/max referral depth/, '... due to max referral depth being reached';
}





###############################################################################
### Helper method to generate LDIF files, and auto-remove them when we're done.
###############################################################################
my @files_to_remove;
END { unlink @files_to_remove; }

sub generate_ldif {
    my ($file, $host, $port) = @_;
    write_file $file, qq{
dn: dc=example,dc=com
objectClass: dcObject
objectClass: referral
dc: example
ref: ldap://${host}:${port}/dc=example,dc=com
};
    push @files_to_remove, $file;
}
