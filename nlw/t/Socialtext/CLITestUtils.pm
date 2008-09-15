package t::Socialtext::CLITestUtils;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Exporter';
our @EXPORT_OK = qw/expect_success expect_failure/;
use Test::More;

BEGIN {
    unless (
        eval {
            require Test::Output;
            Test::Output->import();
            1;
        }
        ) {
        plan skip_all => 'These tests require Test::Output to run.';
    }
}

our $LastExitVal;
no warnings 'redefine';
*Socialtext::CLI::_exit = sub { $LastExitVal = shift; die 'exited'; };

sub expect_success {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $sub    = shift;
    my $expect = shift;
    my $desc   = shift;

    my $test = ref $expect ? \&stdout_like : \&stdout_is;

    local $LastExitVal;
    $expect = [$expect] unless ref($expect) and ref($expect) eq 'ARRAY';
    for my $e (@$expect) {
        $test->( sub { eval { $sub->() } }, $e, $desc );
        warn $@ if $@ and $@ !~ /exited/;
        is( $LastExitVal, 0, 'exited with exit code 0' );
    }
}

sub expect_failure {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $sub    = shift;
    my $expect = shift;
    my $desc   = shift;
    my $error_code = shift || 1;

    my $test = ref $expect ? \&stderr_like : \&stderr_is;

    local $LastExitVal;
    $test->(
        sub {
            eval { $sub->() };
        },
        $expect,
        $desc
    );
    warn "expect_failed: $@" if $@ and $@ !~ /exited/;
    is( $LastExitVal, $error_code, "exited with exit code $error_code" );
}

1;
