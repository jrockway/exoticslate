#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Socialtext::File qw/get_contents/;

my $schema_dir = "$FindBin::Bin/../etc/socialtext/db/";
my $schema_file = "$schema_dir/socialtext-schema.sql";
my @sql_patches = glob("$schema_dir/*-to-*.sql");

plan tests => @sql_patches * 2 + 3;

ok -d $schema_dir;
ok -e $schema_file;
my $schema = get_contents($schema_file);
like $schema, qr/\QINSERT INTO "System" VALUES ('socialtext-schema-version',\E/,
    'schema includes setting the version';

for my $s (@sql_patches) {
    (my $name = $s) =~ s#.+/##;
    my $contents = get_contents($s);
    like $contents, qr/^BEGIN;/is, "$s starts with BEGIN";
    like $contents, qr/COMMIT;$/is, "$s ends with COMMIT";
}


