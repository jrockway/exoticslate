#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More qw/no_plan/;

BEGIN {
    use_ok 'Socialtext::Timer';
}

Singleton_no_reset: {
    Socialtext::Timer->Start('funky');
    Socialtext::Timer->Start('unstopped');
    sleep 1;
    Socialtext::Timer->Stop('funky');
    sleep 1;
    my $timings = Socialtext::Timer->Report();
    ok $timings->{funky} >= 1, 'singleton times funky over 1';
    ok $timings->{funky} <= 2, 'singleton times funky under 2';
    ok $timings->{unstopped} >=2, 'simgle times unstopped over 2';
    ok $timings->{unstopped} <=3, 'simgle times unstopped under 3';
    ok !exists($timings->{overall}), 'no overall timer is present';
}
