#!/usr/bin/env perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext tests => 6;

BEGIN { use_ok("Socialtext::Paths") }
fixtures('admin');

STORAGE_DIRECTORY_PATH: {
    my $dir = Socialtext::Paths::storage_directory();
    ok( defined($dir), "Ensure storage_directory() returns something." );
    like($dir, qr{t/tmp/root/storage/?$}, "Ensure the path looks correct.");
    ok((-d $dir), "Ensure storage directory exists: $dir" );
}

STORAGE_DIRECTORY_SUBDIR: {
    my $dir = Socialtext::Paths::storage_directory("cows-love-matthew");
    ok( defined($dir),
        "Ensure storage_directory(cows-love-matthew) returns something." );
    like( $dir, qr{t/tmp/root/storage/cows-love-matthew/?$},
        "Ensure the path looks correct." );
}
