#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More;
use Socialtext::File qw/get_contents/;
use FindBin;

my $schema_dir  = "$FindBin::Bin/../etc/socialtext/db/";
my $schema_file = "$schema_dir/socialtext-schema.sql";
my @sql_patches = glob("$schema_dir/*-to-*.sql");

plan tests => @sql_patches * 3 + 9;

Schema_is_okay: {
    ok -d $schema_dir;
    ok -e $schema_file;

    my @patches = sort {
        (my $aver = $a) =~ s/.+-to-(\d+)\.sql/$1/;
        (my $bver = $b) =~ s/.+-to-(\d+)\.sql/$1/;
        return $bver <=> $aver
    } @sql_patches;
    my $highest = shift @patches;
    (my $to_version = $highest) =~ s/.+-to-(\d+)\.sql/$1/;
    my $schema = get_contents($schema_file);
    like $schema,
        qr/\QINSERT INTO "System" VALUES ('socialtext-schema-version', '$to_version')\E/,
        'schema includes setting the version';

    like $schema,
        qr/\QCREATE FUNCTION is_page_contribution/,
        'schema has the is_page_contribution function';

    like $schema,
        qr/CREATE INDEX ix_page_events_contribs_actor_time\b/,
        "index on the is_page_contribution function didn't get accidentally dropped";

    like $schema,
        qr/ADD CONSTRAINT workspace_created_by_user_id_fk[^;]+ON DELETE RESTRICT;/,
        "foreign key on Workspace.created_by_user_id doesn't cascade deletes";

    like $schema,
        qr/ADD CONSTRAINT page_creator_id_fk[^;]+ON DELETE RESTRICT;/,
        "foreign key on page.creator_id doesn't cascade deletes";

    like $schema,
        qr/ADD CONSTRAINT page_last_editor_id_fk[^;]+ON DELETE RESTRICT;/,
        "foreign key on page.last_editor_id doesn't cascade deletes";

    Truncate_trouble: {
        # We take advantage of TRUNCATE during appliance restore.  We should
        # make sure to not add new dependencies on the `page` table without
        # updating the appliance restore code.  If this test fails, make sure
        # appliance is updated before you fix this test.
        my @page_deps;
        while($schema =~ m/ALTER TABLE ONLY (\w+)[^;]+ REFERENCES page\(/smg) {
            push @page_deps, $1;
        }
        is join(', ', @page_deps), 'event, page_tag',
            'page table dependencies match appliance expectations';
    }
}

Migrations_are_okay: {
    for my $s (@sql_patches) {
        (my $name = $s) =~ s#.+/##;
        my $contents = get_contents($s);
        like $contents, qr/^BEGIN;/is,  "$s starts with BEGIN";
        like $contents, qr/COMMIT;$/is, "$s ends with COMMIT";
        like $contents, qr/socialtext-schema-version/,
            'patch file mentions the version number';
    }
}

