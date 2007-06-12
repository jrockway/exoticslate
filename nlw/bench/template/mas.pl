#!/usr/bin/env perl
# @COPYRIGHT@
use warnings;
use strict;

use HTML::Mason::Interp;

my $iters = shift || 1;
my @list_items = qw(alpha beta gamma);

my $interp = HTML::Mason::Interp->new(
    data_dir => '/tmp/nlw-bench-mason-data',
    static_source => 1
);
my %config = (
    foo => 'bar',
    baz => 'quux',
    title => 'Test page',
    list => \@list_items,
);

for (1 .. $iters) {
    $interp->exec('/templ.mas', config => \%config);
}

