#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use YAML qw();
use mocked 'Socialtext::Log', qw(:tests);
use Test::Socialtext tests => 8;

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
