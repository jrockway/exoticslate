#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More;
use Socialtext::Migration;

my $migration_dir = 'share/migrations';
my @migrations    = Socialtext::Migration::find_migrations($migration_dir);

plan tests => scalar(@migrations) + 1;

Duplicate_migration_check: {
    my %nums_seen;
    for my $d (@migrations) {
        my $num = $d->{num};
        if ($nums_seen{$num}) {
            ok 0, "duplicate migration ($num) - $d->{name} and "
                . "$nums_seen{$num}{name}";
        }
        else {
            $nums_seen{$num} = $d;
            ok 1, $d->{name};
        }
    }
}

Un_named_migration_check: {
    my %okay_unnumbered = map { $_ => 1 } qw/add-column/;
    my @unnumbered =
        grep { !m/^XX-/ }
        grep { !$okay_unnumbered{$_} }
        grep { !m/^\d+-/ }
        map { s/\Q$migration_dir\E\///; $_ } glob("$migration_dir/*");

    is_deeply \@unnumbered, [], 'No un-numbered migrations';
}
