#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use mocked 'Net::LDAP';
use mocked 'Socialtext::Log', qw(:tests);
use Test::Socialtext tests => 34;
use Test::MockObject::Extends;

use_ok 'Socialtext::LDAP';

###############################################################################
### TEST DATA
###############################################################################
our %data = (
    base => 'ou=Development,dc=example,dc=com',
    host => '127.0.0.1',
    port => 389,
    attr_map => {
        user_id         => 'dn',
        username        => 'cn',
        email_address   => 'mail',
        first_name      => 'gn',
        last_name       => 'sn',
        },
);

###############################################################################
### MANUALLY REPLACE 'ST::LDAP::Config->load()' so that it always uses our
### test data from above.
###
### We always want to use this test data, and this is the easiest way to mock
### this in.
###############################################################################
{
    no strict 'refs';
    no warnings;
    *Socialtext::LDAP::Config::load = sub {
        return Socialtext::LDAP::Config->new(%data);
        };
}

###############################################################################
# List of available LDAP connections; only "Default"
available_ldap_connections: {
    my @conns = Socialtext::LDAP->available();
    is @conns, 1, 'only one available LDAP configuration';
    is $conns[0], 'Default', '... the "Default" one';
}

###############################################################################
# Fail to read configuration.
get_configuration_failure: {
    no strict 'refs';
    no warnings;
    local *Socialtext::LDAP::Config::load = sub { };

    my $config = Socialtext::LDAP->config('Default');
    ok !$config, 'failed to load LDAP config';
}

###############################################################################
# Get named configuration.
# - doesn't matter what the name is (current implementation always reads from
#   the same YAML file), but it should return the right thing
get_configuration_named: {
    my $config = Socialtext::LDAP->config('Foo');
    isa_ok $config, 'Socialtext::LDAP::Config';
}

###############################################################################
# Get default configuration.
get_configuration_default: {
    my $config = Socialtext::LDAP->default_config();
    isa_ok $config, 'Socialtext::LDAP::Config';
}

###############################################################################
# Connect w/unknown LDAP back-end; fails to load
connect_failure_unknown_backend: {
    my $config = Socialtext::LDAP::Config->new(%data);
    $config->backend('Foo');
    clear_log();

    my $ldap = Socialtext::LDAP->connect($config);
    ok !$ldap, 'connect failure; unknown LDAP back-end';

    # VERIFY logs; make sure we failed for the right reason
    is logged_count(), 1, '... logged right number of entries';
    next_log_like 'error', qr/unable to load.*Foo/, '... unable to load Foo back-end';
}

###############################################################################
# Connect w/invalid config; fails to instantiate
connect_failure_to_instantiate_backend: {
    my $config = Socialtext::LDAP::Config->new(%data);
    $config->backend('Foo');
    clear_log();

    local %INC = %INC;
    $INC{'Socialtext/LDAP/Foo.pm'} = 1;

    my $ldap = Socialtext::LDAP->connect($config);
    ok! $ldap, 'connect failure; unable to instantiate LDAP back-end';

    # VERIFY logs; make sure we failed for the right reason
    is logged_count(), 1, '... logged right number of entries';
    next_log_like 'error', qr/unable to instantiate.*Foo/, '... unable to instantiate Foo back-end';
}

###############################################################################
# Connect, default back-end
connect_default_backend: {
    Net::LDAP->set_mock_behaviour();
    clear_log();

    my $config = Socialtext::LDAP::Config->new(%data);

    my $ldap = Socialtext::LDAP->connect($config);
    isa_ok $ldap, 'Socialtext::LDAP::Base', 'used default back-end';

    # VERIFY mocks; want to make sure connection is bound
    my $mock = Net::LDAP->mocked_object();
    $mock->called_ok( 'bind' );
}

###############################################################################
# Connect, explicit back-end
connect_explicit_backend: {
    Net::LDAP->set_mock_behaviour();
    
    my $config = Socialtext::LDAP::Config->new(%data);
    $config->backend('OpenLDAP');

    my $ldap = Socialtext::LDAP->connect($config);
    isa_ok $ldap, 'Socialtext::LDAP::OpenLDAP', 'used OpenLDAP back-end';

    # VERIFY mocks; want to make sure connection is bound
    my $mock = Net::LDAP->mocked_object();
    $mock->called_ok( 'bind' );
}

###############################################################################
# Instantiation; failure to read configuration
instantiation_failure_to_read_config: {
    no strict 'refs';
    no warnings;
    local *Socialtext::LDAP::Config::load = sub { };

    my $ldap = Socialtext::LDAP->new();
    ok !$ldap, 'failed to instantiate; failed to read config';
}

###############################################################################
# Instantiation; connection failure
instantiation_connection_failure: {
    Net::LDAP->set_mock_behaviour(
        connect_fail => 1,
        );
    clear_log();

    my $ldap = Socialtext::LDAP->new();
    ok !$ldap, 'failed to instantiate; connection failure';

    # VERIFY logs; make sure we failed for the right reason
    is logged_count(), 1, '... logged right number of entries';
    next_log_like 'error', qr/unable to connect/, '... unable to connect';
}

###############################################################################
# Instantiation; bind failure
instantiation_bind_failure: {
    Net::LDAP->set_mock_behaviour(
        bind_fail => 1,
        );
    clear_log();

    my $ldap = Socialtext::LDAP->new();
    ok !$ldap, 'failed to instantiate; bind failure';

    # VERIFY logs; make sure we failed for the right reason
    is logged_count(), 1, '... logged right number of entries';
    next_log_like 'error', qr/unable to bind/, '... unable to bind';
}

###############################################################################
# Instantiation
instantiation: {
    Net::LDAP->set_mock_behaviour();
    clear_log();

    my $ldap = Socialtext::LDAP->new();
    isa_ok $ldap, 'Socialtext::LDAP::Base';

    # VERIFY mocks; want to make sure connection is bound
    my $mock = Net::LDAP->mocked_object();
    $mock->called_ok( 'bind' );
}

###############################################################################
# Authentication; failure to read config
authentication_failure_to_read_config: {
    no strict 'refs';
    no warnings;
    local *Socialtext::LDAP::Config::load = sub { };

    my $auth_ok = Socialtext::LDAP->authenticate('dn', 'password');
    ok !$auth_ok, 'auth; failed to read config';
}

###############################################################################
# Authentication; failure to connect
authentication_failure_to_connect: {
    Net::LDAP->set_mock_behaviour(
        connect_fail => 1,
        );
    clear_log();

    my $auth_ok = Socialtext::LDAP->authenticate('dn', 'password');
    ok! $auth_ok, 'auth; failed to connect';

    # VERIFY logs; want to make sure we failed for the right reason
    is logged_count(), 1, '... logged right number of reasons';
    next_log_like 'error', qr/unable to connect/, '... failed to connect';
}

###############################################################################
# Authentication; auth failure
authentication_failure: {
    Net::LDAP->set_mock_behaviour(
        bind_fail => 1,
        );
    clear_log();

    my $auth_ok = Socialtext::LDAP->authenticate('dn', 'password');
    ok! $auth_ok, 'auth; failed to authenticate';

    # VERIFY logs; want to make sure we failed for the right reason
    is logged_count(), 1, '... logged right number of reasons';
    next_log_like 'info', qr/authentication failed/, '... auth failure';
}

###############################################################################
# Authentication success
authentication_success: {
    Net::LDAP->set_mock_behaviour(
        bind_requires_authentication => 1,
        );

    my $auth_ok = Socialtext::LDAP->authenticate('dn', 'password');
    ok $auth_ok, 'authentication success';
}

###############################################################################
# Authentication success (anonymous)
authentication_anonymous_success: {
    Net::LDAP->set_mock_behaviour();

    my $auth_ok = Socialtext::LDAP->authenticate();
    ok $auth_ok, 'authentication (anonymous) success';
}
