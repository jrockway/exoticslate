#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More qw/no_plan/;

BEGIN {
    use_ok 'Socialtext::Timer';
}

Basic_usage: {
    my $t = Socialtext::Timer->new;
    sleep 1;
    ok $t->elapsed >= 1, 'timer worked';
}

Singleton_usage: {
    Socialtext::Timer->Reset();
    sleep 1;
    Socialtext::Timer->Start('funky');
    Socialtext::Timer->Start('unstopped');
    sleep 1;
    Socialtext::Timer->Stop('funky');
    sleep 1;
    my $timings = Socialtext::Timer->Report();
    ok $timings->{overall} >= 3, 'singleton times overall';
    ok $timings->{funky} >= 1, 'singleton times funky over 1';
    ok $timings->{funky} <= 2, 'singleton times funky under 2';
    ok $timings->{unstopped} >=2, 'simgle times unstopped over 2';
    ok $timings->{unstopped} <=3, 'simgle times unstopped under 3';
}
