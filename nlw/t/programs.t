#!/usr/loca/bin/perl -w
# @COPYRIGHT@

use strict;
use warnings;

use Test::More;
use File::Basename qw(basename dirname);
use File::Spec::Functions qw(catdir catfile);
use Cwd qw(abs_path getcwd);

my $BASE_DIR = abs_path(catdir(dirname(__FILE__), '..'));

BEGIN {
    unless ( eval { require Test::Program; Test::Program->import(); 1 } ) {
        plan skip_all => 'These tests require Test::Program to run.';
    }
}

# Put non-compiling program names in the passed in list,
# so they are done as TODO tests.
my @bin_programs = make_prog_list('bin/', qw(
));

my @dev_bin_programs = make_prog_list('dev-bin/', qw(
    import-user-data-1
    memory-watchdog
    diffable
    l10n-nlw-to-wiki
    st-create-account-data
    st-qa-growth-report-populate-db
    st-qa-growth-report-add-members
));

my @programs = grep {-f} @bin_programs, 
                         @dev_bin_programs;

plan tests => scalar @programs * 3;

my $curdir = abs_path(getcwd());
foreach my $program ( @programs ) {
    for my $dir ( ($curdir, '/tmp') ) {
        chdir $dir;
        program_compiles_ok( $program )
            or diag("$program failed to compile while CWD = $dir\n");
    }
    program_pod_ok( $program );
}

sub make_prog_list {
    my $dir = shift;
    my @skips = @_;
    my %skips = map {($_,1)} @skips;

    my $cmd = catfile($BASE_DIR, "dev-bin", "perl-bin-files");
    $dir = catdir($BASE_DIR, $dir);
    my @progs = `$cmd $dir`;
    chomp(@progs);

    return grep { !$skips{ basename($_) } } @progs;
}
