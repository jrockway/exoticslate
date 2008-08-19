#!/usr/bin/env perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext tests => 5;
use Socialtext::Paths;
use File::Path qw/mkpath/;
fixtures('db');

# This is normally created by fdefs, but doesn't exist in the unit-test
# environment
my $dir = Socialtext::Paths::storage_directory("db-backups");
mkpath $dir unless -d $dir;

ST_DB_DUMP_DATA: {
    my $rv = system("bin/st-db", "dump");
    is($rv, 0, "Ensure st-db dump has return code of 0");

    ok((-d $dir), "db-backups directory exists");
    $rv = opendir(my $fh, $dir);
    ok($rv, "Safely opened $dir");
    my @files = grep { /\.sql$/  } readdir($fh);
    is(scalar(@files), 1, "Found exactly one file");
    like($files[0], qr/^NLW_.*?-dump\.\d+\.sql$/, "Ensure we got a dump file");
}
