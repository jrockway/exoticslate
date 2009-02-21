#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;

use YAML;
use Test::More;
use Test::Exception;
use File::Path 'mkpath';
use Socialtext::System qw/shell_run/;
use Socialtext::Schema;

my $real_dir = 'etc/socialtext/db';
my $fake_dir = 't/tmp/etc/socialtext/db';
my $log_dir = 't/tmp/log';
my $backup_dir = 't/tmp/db-backups';
my $START_SCHEMA = 2;
my $latest_schema = $START_SCHEMA;

# Set up directories and copy schema migrations into t/tmp
{
    mkpath $log_dir unless -d $log_dir;
    mkpath $fake_dir unless -d $fake_dir;
    mkpath $backup_dir unless -d $backup_dir;
    ($latest_schema) = reverse sort { $a <=> $b }
                        map { m/-\d+-to-(\d+)\.sql/ }
                       glob("$real_dir/socialtext-*-to-*.sql");

    for my $cur ($START_SCHEMA .. $latest_schema) {
        my $prev = $cur - 1;
        my $file = "socialtext-$prev-to-$cur.sql";
        open my $in, "$real_dir/$file"
            or die "Can't open $real_dir/$file: $!";
        open my $out, ">$fake_dir/$file"
            or die "Can't open $fake_dir/$file: $!";
        while (<$in>) {
            # change backup directories that don't exist here
            s{/var/www/socialtext/storage/db-backups}{$backup_dir}g;
            print $out $_;
        }
        close $out or die "Can't write to $fake_dir/$file: $!";
    }
}

plan tests => ($latest_schema - $START_SCHEMA) + 1;

# Set up the initial database
diag "loading config...\n";
my $schema_config = YAML::LoadFile("$real_dir/socialtext.yaml");

diag "Creating schema object...\n";
my $schema = Socialtext::Schema->new(%$schema_config);
$schema->{no_add_required_data} = $schema->{quiet} = 1;

diag "Recreating schema...\n";
$schema->recreate('schema-file' => 't/test-data/socialtext-schema.sql');

# Check each schema
for ( $START_SCHEMA+1 .. $latest_schema ) {
    lives_ok { $schema->sync( to_version => $_ ) }
             "Schema migration $_";
    die "Can't continue" if $@;
}

# Now check that the final result is the same as socialtext-schema.sql
my $generated_schema = 't/tmp/generated-schema.sql';
shell_run "dump-schema $generated_schema";

my $diff = qx{diff -du $generated_schema $real_dir/socialtext-schema.sql};
is $diff, '', "Zero length diff";

