#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::More qw/no_plan/;
use Socialtext::Migration;

my $migration_dir = 'share/migrations';
my @migrations = Socialtext::Migration::find_migrations($migration_dir);

Duplicate_migration_check: {
    my %nums_seen;
    for my $d (@migrations) {
        my $num = $d->{num};
        warn "num=$num name=$d->{name}";
        if ($nums_seen{$num}) {
            ok 0, "duplicate migration ($num) - $d->{name} and "
                  . "$nums_seen{$num}{name}";
        }
        else {
            $nums_seen{$num} = $d;
        }
    }
}

ok 1;
