#!/usr/bin/env perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext tests => 5;
use Socialtext::Paths;
fixtures("admin_no_pages");

ST_DB_DUMP_DATA: {
    my $rv = system("bin/st-db", "--dump-data");
    is($rv, 0, "Ensure st-db --dump-data has return code of 0");

    my $dir = Socialtext::Paths::storage_directory("db-backups");
    ok((-d $dir), "db-backups directory exists");
    $rv = opendir(my $fh, $dir);
    ok($rv, "Safely opened $dir");
    my @files = grep { /\.sql$/  } readdir($fh);
    is(scalar(@files), 1, "Found exactly one file");
    like($files[0], qr/^NLW_.*?-dump\.\d+\.sql$/, "Ensure we got a dump file");
}
