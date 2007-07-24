#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More tests => 16;
use File::Temp qw/tempdir/;

my $gen_config = "dev-bin/gen-config";
ok -x $gen_config;

my $test_root = tempdir( CLEANUP => 1 );

Usage: {
    my $output = run_test('');
    like $output, qr/\QNot run with --sitewide, and no --root dir parameter given.\E/;
}

Dev_env: {
    my $output = run_test("--quiet --root $test_root --ports-start-at 20000 "
                          . "--apache-proxy=1 --socialtext-open=0 --dev=0");
    my @files = qw(
        apache2/nlw-apache2.conf
        apache2/auto-generated.d/nlw.conf
        apache-perl/nlw-httpd.conf
        apache-perl/auto-generated.d/nlw.conf
        socialtext/shortcuts.yaml
        socialtext/uri_map.yaml
        socialtext/auth_map.yaml
    );
    for my $f (@files) {
        my $full_path = "$test_root/etc/$f";
        like $output, qr#\Q$full_path\E#;
        ok -e $full_path, "$full_path exists";
    }
}

exit;

sub run_test {
    my $args = shift;
    return qx($^X $gen_config $args 2>&1);
}
