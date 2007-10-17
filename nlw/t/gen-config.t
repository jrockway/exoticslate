#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More tests => 18;
use File::Temp qw/tempdir/;

my $gen_config = "dev-bin/gen-config";
ok -x $gen_config;

my $test_root = tempdir( CLEANUP => 1 );

Usage: {
    # NOTE: this usage test is really only valid for a non-dev environment
    # when running in a dev-environment, which is what a fresh-dev-env-from-scratched
    # world is going to look like, the usage error won't get spewed from gen-config.
    # Now that we don't re-gen the configuration on every test, the fact that we are
    # in a dev environment is being remembered in Socialtext::Build::ConfigureValues.pm
    # for us so we need to override that setting in order to produce the error.
    my $output = run_test('--dev=0');
    like $output, qr/\QNot run with --sitewide, and no --root dir parameter given.\E/;
}

Dev_env: {
    my $output = run_test("--quiet --root $test_root --ports-start-at 20000 "
                          . "--apache-proxy=1 --socialtext-open=0 --dev=0");
    my @files = qw(
        apache2/nlw-apache2.conf
        apache2/auto-generated.d/nlw.conf
        apache2/conf.d/socialtext-empty.conf
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
