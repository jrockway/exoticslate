#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More tests => 1;

Tests_without_plan: {
    my $np = join('_', 'no', 'plan'); # obfuscate
    my @without_plans = qx(find t -name *.t | xargs grep -l $np);
    chomp @without_plans;
    my @without_plan_ok = (
        # These tests are "grandfathered" in, but we should fix them
        't/live/rest/recent-changes.t',
        't/live/rest/workspace-pages.t',
    );
    is_deeply [ sort @without_plans ], [ sort @without_plan_ok ],
        'tests with no plan are acceptable';
}
