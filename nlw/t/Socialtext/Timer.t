#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More qw/no_plan/;
use Time::HiRes qw/usleep/;
use Sys::Load qw/getload/;

BEGIN {
    use_ok 'Socialtext::Timer';
}

# Some of these tests like to fail randomly. We think that it's
# because the system is under higher load. Let's dip our toes
# in that water and record where load is so we can prove or
# disprove that theory
my ( $one_min, $five_min, $fifteen_min ) = getload();
warn "Load during test: $one_min, $five_min, $fifteen_min\n";

Basic_usage: {
    my $t = Socialtext::Timer->new;
    sleep 1;
    ok $t->elapsed >= 1, 'timer worked';
}

Singleton_usage: {
    Socialtext::Timer->Reset();
    usleep 1000;
    Socialtext::Timer->Start('funky');
    Socialtext::Timer->Start('unstopped');
    usleep 1000;
    Socialtext::Timer->Stop('funky');
    usleep 1000;
    my $timings = Socialtext::Timer->Report();
    ok $timings->{overall} >= .003,
        "singleton times overall - $timings->{overall}";
    ok $timings->{funky} >= .001,
        "singleton times funky over .001 - $timings->{funky}";
    ok $timings->{funky} <= .03,
        "singleton times funky under .03 - $timings->{funky}";
    ok $timings->{unstopped} >= .002,
        "single times unstopped over .002 - $timings->{unstopped}";
    ok $timings->{unstopped} <= .05,
        "single times unstopped under .05 - $timings->{unstopped}";
}

Singleton_pause: {
    Socialtext::Timer->Reset();
    Socialtext::Timer->Start('pausable');
    usleep 1000;
    Socialtext::Timer->Pause('pausable');
    usleep 1000;
    Socialtext::Timer->Continue('pausable');
    usleep 1000;
    Socialtext::Timer->Pause('pausable');
    usleep 1000;
    Socialtext::Timer->Continue('pausable');
    usleep 1000;
    my $timings = Socialtext::Timer->Report();
    ok $timings->{overall} >= .005,
        "overall time correct - $timings->{overall}";
    ok $timings->{pausable} >= .003,
        "pausable time greater than .003 - $timings->{pausable}";
    ok $timings->{pausable} <= .06,
        "pausable time less than .06 - $timings->{pausable}";
}

Singleton_continue_means_start: {
    Socialtext::Timer->Reset();
    Socialtext::Timer->Continue('pausable');
    usleep 1000;
    Socialtext::Timer->Pause('pausable');
    usleep 1000;
    my $timings = Socialtext::Timer->Report();
    ok $timings->{overall} >= .002,
        "overall time correct - $timings->{overall}";
    ok $timings->{pausable} >= .001,
        "pausable time greater than .001 - $timings->{pausable}";
    ok $timings->{pausable} <= .02,
        "pausable time less than .02 - $timings->{pausable}";
}

Singleton_continue_twice: {
    # basically just checking for lack of blow up when
    # we continue a timer that was never paused, but has
    # started
    Socialtext::Timer->Reset();
    Socialtext::Timer->Continue('pausable');
    usleep 1000;
    Socialtext::Timer->Continue('pausable');
    my $timings = Socialtext::Timer->Report();
    ok $timings->{pausable} >= .001,
        "double continue did not blow up - $timings->{pausable}";
}

Singleton_pause_twice: {
    # basically just checking for lack of blow up when
    # we pause a timer that was already paused.
    Socialtext::Timer->Reset();
    usleep 1000;
    Socialtext::Timer->Continue('pausable');
    usleep 1000;
    Socialtext::Timer->Continue('pausable');
    usleep 1000;
    Socialtext::Timer->Pause('pausable');
    usleep 1000;
    Socialtext::Timer->Pause('pausable');
    usleep 1000;
    my $timings = Socialtext::Timer->Report();
    ok $timings->{overall} >= .005,
        "overall time greater than .005 - $timings->{overall}";
    ok $timings->{pausable} >= .004,
        "pausable time greater than .004 - $timings->{pausable}";
    ok $timings->{pausable} <= .09,
        "pausable time less than .09 - $timings->{pausable}";
}
