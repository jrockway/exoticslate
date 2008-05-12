#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use YAML qw();
use File::Spec;
use File::Temp;
use POSIX qw(fcntl_h);
use mocked 'Socialtext::Log', qw(:tests);
use Test::Socialtext tests => 64;

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
        next_log_like 'warning', qr/missing '$required'/, "... ... missing $required";
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
        next_log_like 'warning', qr/missing mapped attribute '$attr'/, "... ... missing $attr";
    }
}

###############################################################################
# Instantiation with full config; should be ok.
instantiation: {
    my $data = YAML::Load($yaml);
    my $config = Socialtext::LDAP::Config->new(%{$data});
    isa_ok $config, 'Socialtext::LDAP::Config', 'valid instantiation';
}

###############################################################################
# Load from non-existent YAML file; should fail
load_nonexistent_file: {
    clear_log();

    my $config = Socialtext::LDAP::Config->load_from('t/doesnt-exist.yaml');
    ok !defined $config, 'load, missing YAML file';

    is logged_count(), 1, '... logged right number of entries';
    next_log_like 'error', qr/error reading LDAP config/, '... ... error reading config';
}

###############################################################################
# Load from invalid YAML file; should fail
load_invalid_yaml: {
    # write out a YAML file with missing fields
    my $fh = File::Temp->new();
    $fh->print( "# YAML file, with invalid LDAP entry\n" );
    $fh->print( "name: Missing All Config\n" );
    $fh->seek( 0, SEEK_SET );

    # run the test
    clear_log();

    my $config = Socialtext::LDAP::Config->load_from($fh);
    ok !defined $config, 'load, invalid YAML file';
    is logged_count(), 2, '... logged right number of entries';
    next_log_like 'warning', qr/config missing/, '... ... config missing something';
    next_log_like 'error', qr/error with LDAP config/, '... ... bad config in file';
}

###############################################################################
# Load from YAML file; should be ok
load_valid_yaml: {
    # write out a valid YAML file
    my $fh = File::Temp->new();
    $fh->print( $yaml );
    $fh->seek( 0, SEEK_SET );

    # run the test
    my $config = Socialtext::LDAP::Config->load_from($fh);
    isa_ok $config, 'Socialtext::LDAP::Config', 'valid load from YAML';
}

###############################################################################
# Save with missing filename; should fail
save_missing_filename: {
    my $data = YAML::Load($yaml);
    my $config = Socialtext::LDAP::Config->new(%{$data});
    isa_ok $config, 'Socialtext::LDAP::Config';
    ok !Socialtext::LDAP::Config->save_to(), 'save without filename';
}

###############################################################################
# Save to YAML file; should be ok
save_ok: {
    my $data = YAML::Load($yaml);
    my $config = Socialtext::LDAP::Config->new(%{$data});
    isa_ok $config, 'Socialtext::LDAP::Config', 'created LDAP config';

    my $tmpfile = File::Spec->catfile(
        File::Spec->tmpdir(),
        "$$.yaml",
        );
    ok !-e $tmpfile, '... temp file does not exist (yet)';
    ok Socialtext::LDAP::Config->save_to($tmpfile, $config), '... saved config to temp file';
    ok -e $tmpfile, '... temp file exists';

    my $reloaded = eval { YAML::LoadFile($tmpfile) };
    ok $reloaded, '... able to reload YAML from temp file';
    is_deeply $reloaded, $data, '... ... and it matches original data';

    unlink $tmpfile;
}

###############################################################################
# Save multiple configuration objects
save_multiple_configurations: {
    # create multiple LDAP config objects
    my $data   = YAML::Load($yaml);

    my $first = Socialtext::LDAP::Config->new(%{$data});
    isa_ok $first, 'Socialtext::LDAP::Config', 'first config';
    $first->name('First LDAP Config');

    my $second = Socialtext::LDAP::Config->new(%{$data});
    isa_ok $second, 'Socialtext::LDAP::Config', 'second config';
    $second->name('Second LDAP Config');

    # save the configs out to disk
    my $tmpfile = File::Spec->catfile(
        File::Spec->tmpdir(),
        "$$.yaml",
        );
    ok !-e $tmpfile, '... temp file does not exist (yet)';
    ok Socialtext::LDAP::Config->save_to($tmpfile, $first, $second), '... saved configs to temp file';
    ok -e $tmpfile, '... temp file exists';

    # verify the contents of the YAML file
    my @reloaded = eval { YAML::LoadFile($tmpfile) };
    ok @reloaded, '... able to reload YAML from temp file';
    is scalar(@reloaded), 2, '... ... and it contains two LDAP configurations';
    is_deeply $reloaded[0], $first, '... ... first looks ok';
    is_deeply $reloaded[1], $second, '... ... second looks ok';

    # remove our tempfile
    unlink $tmpfile;
}

###############################################################################
# Load multiple configuration objects
load_multiple_configurations: {
    # create multiple LDAP config objects
    my $data   = YAML::Load($yaml);

    my $first  = Socialtext::LDAP::Config->new(%{$data});
    isa_ok $first, 'Socialtext::LDAP::Config', 'first config';
    $first->name('First LDAP Config');

    my $second = Socialtext::LDAP::Config->new(%{$data});
    isa_ok $second, 'Socialtext::LDAP::Config', 'second config';
    $second->name('Second LDAP Config');

    # save the LDAP config to disk
    my $tmpfile = File::Spec->catfile(
        File::Spec->tmpdir(),
        "$$.yaml",
    );
    ok !-e $tmpfile, '... temp file does not exist (yet)';
    ok Socialtext::LDAP::Config->save_to($tmpfile, $first, $second), '... saved configs to temp file';
    ok -e $tmpfile, '... temp file exists';

    # load the configurations back out of the YAML file
    my @configs = Socialtext::LDAP::Config->load_from($tmpfile);
    ok @configs, '... able to load YAML from temp file';
    is scalar(@configs), 2, '... ... and it contains two LDAP configurations';
    is_deeply $configs[0], $first, '... ... first looks ok';
    is_deeply $configs[1], $second, '... ... second looks ok';

    # remove our tempfile
    unlink $tmpfile;
}

###############################################################################
# Load FIRST configuration object (when multiple configs exist)
load_first_configuration: {
    # create multiple LDAP config objects
    my $data   = YAML::Load($yaml);

    my $first  = Socialtext::LDAP::Config->new(%{$data});
    isa_ok $first, 'Socialtext::LDAP::Config', 'first config';
    $first->name('First LDAP Config');

    my $second = Socialtext::LDAP::Config->new(%{$data});
    isa_ok $second, 'Socialtext::LDAP::Config', 'second config';
    $second->name('Second LDAP Config');

    # save the LDAP config to disk
    my $tmpfile = File::Spec->catfile(
        File::Spec->tmpdir(),
        "$$.yaml",
    );
    ok !-e $tmpfile, '... temp file does not exist (yet)';
    ok Socialtext::LDAP::Config->save_to($tmpfile, $first, $second), '... saved configs to temp file';
    ok -e $tmpfile, '... temp file exists';

    # load the first configuration back out of the YAML file
    my $config = Socialtext::LDAP::Config->load_from($tmpfile);
    isa_ok $config, 'Socialtext::LDAP::Config', '... read single config from temp file';
    is_deeply $config, $first, '... ... and its the first config';

    # remove our tempfile
    unlink $tmpfile;
}
