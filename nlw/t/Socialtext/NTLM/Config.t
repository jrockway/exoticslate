#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use YAML qw();
use File::Spec;
use File::Temp;
use POSIX qw(fcntl_h);
use mocked 'Socialtext::Log', qw(:tests);
use Test::Socialtext tests => 50;

use_ok( 'Socialtext::NTLM::Config' );

###############################################################################
### TEST DATA
###############################################################################
our $yaml = <<EOY;
domain: SOCIALTEXT
primary: PRIMARY_DC
backup:
  - BACKUP_DC_ONE
  - BACKUP_DC_TWO
EOY

###############################################################################
# Check for required fields on instantiation; domain, primary
check_required_fields: {
    foreach my $required (qw( domain primary )) {
        clear_log();

        my $data = YAML::Load($yaml);
        delete $data->{$required};

        my $config = Socialtext::NTLM::Config->new(%{$data});
        ok !defined $config, "instantiation, missing '$required' parameter";

        is logged_count(), 1, '... logged right number of entries';
        next_log_like 'error', qr/missing '$required'/, "... ... missing $required";
    }
}

###############################################################################
# Instantiation with full config; should be ok.
instantiation: {
    my $data = YAML::Load($yaml);
    my $config = Socialtext::NTLM::Config->new(%{$data});
    isa_ok $config, 'Socialtext::NTLM::Config', 'valid instantiation';
}

###############################################################################
# Load from non-existent YAML file; should fail
load_nonexistent_file: {
    clear_log();

    my $config = Socialtext::NTLM::Config->load_from('t/doesnt-exist.yaml');
    ok !defined $config, 'load, missing YAML file';

    is logged_count(), 1, '... logged right number of entries';
    next_log_like 'error', qr/error reading config/, '... ... error reading config';
}

###############################################################################
# Load from invalid YAML file; should fail
load_invalid_yaml: {
    # write out a YAML file with missing fields
    my $fh = File::Temp->new();
    $fh->print( "# YAML file, with invalid NTLM entry\n" );
    $fh->print( "domain: MISSING_ALL_CONFIG\n" );
    seek( $fh, 0, SEEK_SET );

    # run the test
    clear_log();

    my $config = Socialtext::NTLM::Config->load_from($fh);
    ok !defined $config, 'load, invalid YAML file';
    is logged_count(), 2, '... logged right number of entries';
    next_log_like 'error', qr/config missing/, '... ... config missing something';
    next_log_like 'error', qr/error with config/, '... ... bad config in file';
}

###############################################################################
# Load from YAML file; should be ok
load_valid_yaml: {
    # write out a valid YAML file
    my $fh = File::Temp->new();
    $fh->print( $yaml );
    seek( $fh, 0, SEEK_SET );

    # run test
    my $config = Socialtext::NTLM::Config->load_from($fh);
    isa_ok $config, 'Socialtext::NTLM::Config', 'valid load from YAML';
}

###############################################################################
# Save with missing filename; should fail
save_missing_filename: {
    my $data = YAML::Load($yaml);
    my $config = Socialtext::NTLM::Config->new(%{$data});
    isa_ok $config, 'Socialtext::NTLM::Config';
    ok !Socialtext::NTLM::Config->save_to(), 'save without filename';
}

###############################################################################
# save to YAML file; should be ok
save_ok: {
    my $data = YAML::Load($yaml);
    my $config = Socialtext::NTLM::Config->new(%{$data});
    isa_ok $config, 'Socialtext::NTLM::Config', 'created NTLM config';

    my $tmpfile = File::Spec->catfile(
        File::Spec->tmpdir(),
        "$$.yaml",
    );
    ok !-e $tmpfile, '... temp file does not exist (yet)';
    ok Socialtext::NTLM::Config->save_to($tmpfile, $config), '... saved config to temp file';
    ok -e $tmpfile, '... temp file exists';

    # verify the contents of the YAML file
    my $reloaded = eval { YAML::LoadFile($tmpfile) };
    ok $reloaded, '... able to reload YAML from temp file';
    is_deeply $reloaded, $data, '... ... and it matches original data';

    # remove our tempfile
    unlink $tmpfile;
}

###############################################################################
# Save multiple configuration objects
save_multiple_configurations: {
    # create multiple NTLM config objects
    my $data = YAML::Load($yaml);

    my $first = Socialtext::NTLM::Config->new(%{$data});
    isa_ok $first, 'Socialtext::NTLM::Config', 'first config';
    $first->domain('FIRST_DOMAIN');

    my $second = Socialtext::NTLM::Config->new(%{$data});
    isa_ok $second, 'Socialtext::NTLM::Config', 'second config';
    $second->domain('SECOND_DOMAIN');

    # save the configs out to disk
    my $tmpfile = File::Spec->catfile(
        File::Spec->tmpdir(),
        "$$.yaml",
    );
    ok !-e $tmpfile, '... temp file does not exist (yet)';
    ok Socialtext::NTLM::Config->save_to($tmpfile, $first, $second), '... saved configs to temp file';
    ok -e $tmpfile, '... temp file exists';

    # verify the contents of the YAML file
    my @reloaded = eval { YAML::LoadFile($tmpfile) };
    ok @reloaded, '... able to reload YAML from temp file';
    is scalar(@reloaded), 2, '... ... and it contains two NTLM configurations';
    is_deeply $reloaded[0], $first, '... ... first looks ok';
    is_deeply $reloaded[1], $second, '... ... second looks ok';

    # remove our tempfile
    unlink $tmpfile;
}

###############################################################################
# Load multiple configuration objects
load_multiple_configurations: {
    # create multiple NTLM config objects
    my $data = YAML::Load($yaml);

    my $first = Socialtext::NTLM::Config->new(%{$data});
    isa_ok $first, 'Socialtext::NTLM::Config', 'first config';
    $first->domain('FIRST_DOMAIN');

    my $second = Socialtext::NTLM::Config->new(%{$data});
    isa_ok $second, 'Socialtext::NTLM::Config', 'second config';
    $second->domain('SECOND_DOMAIN');

    # save the NTLM config to disk
    my $tmpfile = File::Spec->catfile(
        File::Spec->tmpdir(),
        "$$.yaml",
    );
    ok !-e $tmpfile, '... temp file does not exist (yet)';
    ok Socialtext::NTLM::Config->save_to($tmpfile, $first, $second), '... saved configs to temp file';
    ok -e $tmpfile, '... temp file exists';

    # load the configurations back out of the YAML file
    my @reloaded = Socialtext::NTLM::Config->load_from($tmpfile);
    ok @reloaded, '... able to load YAML from temp file';
    ok @reloaded, '... able to reload YAML from temp file';
    is scalar(@reloaded), 2, '... ... and it contains two NTLM configurations';
    is_deeply $reloaded[0], $first, '... ... first looks ok';
    is_deeply $reloaded[1], $second, '... ... second looks ok';

    # remove our tempfile
    unlink $tmpfile;
}

###############################################################################
# Load FIRST configuration object (when multiple configs exist)
load_first_configuration: {
    # create multiple NTLM config objects
    my $data = YAML::Load($yaml);

    my $first = Socialtext::NTLM::Config->new(%{$data});
    isa_ok $first, 'Socialtext::NTLM::Config', 'first config';
    $first->domain('FIRST_DOMAIN');

    my $second = Socialtext::NTLM::Config->new(%{$data});
    isa_ok $second, 'Socialtext::NTLM::Config', 'second config';
    $second->domain('SECOND_DOMAIN');

    # save the NTLM config to disk
    my $tmpfile = File::Spec->catfile(
        File::Spec->tmpdir(),
        "$$.yaml",
    );
    ok !-e $tmpfile, '... temp file does not exist (yet)';
    ok Socialtext::NTLM::Config->save_to($tmpfile, $first, $second), '... saved configs to temp file';
    ok -e $tmpfile, '... temp file exists';

    # load the first configuration back out of the YAML file
    my $reloaded = Socialtext::NTLM::Config->load_from($tmpfile);
    isa_ok $reloaded, 'Socialtext::NTLM::Config', '... read single config from temp file';
    is_deeply $reloaded, $first, '... ... and its the first config';

    # remove our tempfile
    unlink $tmpfile;
}
