#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use YAML qw();
use mocked 'Socialtext::Log', qw(:tests);
use Test::Socialtext tests => 23;

use_ok( 'Socialtext::LDAP::Config' );

###############################################################################
### TEST DATA
###############################################################################
our $yaml =<<EOY;
id: 1deadbeef1
name: Authenticated LDAP
backend: OpenLDAP
base: ou=Development,dc=my-domain,dc=com
host: 127.0.0.1
port: 389
bind_user: cn=Manager,ou=Development,dc=my-domain,dc=com
bind_password: abc123
filter: '(objectClass=inetOrgPerson)'
ttl: 300
attr_map:
    user_id: dn
    username: cn
    email_address: mail
    first_name: gn
    last_name: sn
EOY

###############################################################################
# Check for required fields on instantiation; host, attr_map
check_required_fields: {
    foreach my $required (qw( host attr_map )) {
        clear_log();

        my $data = YAML::Load($yaml);
        delete $data->{$required};

        my $config = Socialtext::LDAP::Config->new(%{$data});
        ok !defined $config, "instantiation, missing '$required' parameter";

        is logged_count(), 1, '... logged right number of entries';
        next_log_like 'error', qr/missing '$required'/, "... ... missing $required";
    }
}

###############################################################################
# Check for required mapped attributes; user_id, username, email_address,
# first_name, last_name
check_required_mapped_attributes: {
    foreach my $attr (qw( user_id username email_address first_name last_name )) {
        clear_log();

        my $data = YAML::Load($yaml);
        delete $data->{attr_map}{$attr};

        my $config = Socialtext::LDAP::Config->new(%{$data});
        ok !defined $config, "instantiation, missing '$attr' mapped attribute";

        is logged_count(), 1, '... logged right number of entries';
        next_log_like 'error', qr/missing mapped attribute '$attr'/, "... ... missing $attr";
    }
}

###############################################################################
# Instantiation with full config; should be ok.
instantiation: {
    my $data = YAML::Load($yaml);
    my $config = Socialtext::LDAP::Config->new(%{$data});
    isa_ok $config, 'Socialtext::LDAP::Config', 'valid instantiation';
}
