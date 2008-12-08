#!/usr/bin/perl
# @COPYRIGHT@

# Many of our customers experience this problem right now. 
#  * Pointroll
#  * ATSU ( will in the future. )
#  * ABC
# Making sure this use case is covered in tests so we can fix it some day.

use strict;
use warnings;
use Socialtext::LDAP;
use Socialtext::User;
use Socialtext::User::Default::Factory;
use Test::Socialtext::Bootstrap::OpenLDAP;
use Test::Warn;
use Test::Socialtext tests => 5;

fixtures( 'db' );

###############################################################################
# Fire up LDAP, and populate it with some users.
my $ldap = Test::Socialtext::Bootstrap::OpenLDAP->new();
isa_ok $ldap, 'Test::Socialtext::Bootstrap::OpenLDAP';

# ... custom config, so that we can set the "last name" to a field that could
#     be null
$ldap->ldap_config->{attr_map}{last_name} = 'title';
$ldap->add_to_ldap_config();

# ... populate OpenLDAP
ok $ldap->add_ldif('t/test-data/ldap/base_dn.ldif'), 'added base_dn';
ok $ldap->add_ldif('t/test-data/ldap/people.ldif'), 'added people';

# Add 'good' data.
$ldap->add(
    'cn=No Name,dc=example,dc=com',
    objectClass  => 'inetOrgPerson',
    cn           => 'No Name',
    gn           => 'No',
    title        => 'Name',
    sn           => 'UNUSED',
    mail         => 'no.name@example.com',
    userPassword => 'foobar'
);

# This is our 'happy path'.
my $user = Socialtext::User->new( email_address => 'no.name@example.com' );
isa_ok $user, 'Socialtext::User';

# This tests a null last_name field.
my $other_user = Socialtext::User->new( email_address => 'john.doe@example.com' );
isa_ok $user, 'Socialtext::User';
