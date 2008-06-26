#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More qw/no_plan/;
use Time::HiRes qw/usleep/;

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
    usleep 1000;
    Socialtext::Timer->Start('funky');
    Socialtext::Timer->Start('unstopped');
    usleep 1000;
    Socialtext::Timer->Stop('funky');
    usleep 1000;

    my $timings = Socialtext::Timer->Report();
    ok $timings->{overall} >= .003, 'singleton times overall';
    ok $timings->{funky} >= .001, 'singleton times funky over .001';
    ok $timings->{funky} <= .02, 'singleton times funky under .02';
    ok $timings->{unstopped} >= .002, 'single times unstopped over .002';
    ok $timings->{unstopped} <= .03, 'single times unstopped under .03';
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
    ok $timings->{overall} >= .005, 'overall time correct';
    ok $timings->{pausable} >= .003, 'pausable time greater than .003';
    ok $timings->{pausable} <= .04, 'pausable time less than .04';
}

Singleton_continue_means_start: {
    Socialtext::Timer->Reset();
    Socialtext::Timer->Continue('pausable');
    usleep 1000;
    Socialtext::Timer->Pause('pausable');
    usleep 1000;
    my $timings = Socialtext::Timer->Report();
    ok $timings->{overall} >= .002, 'overall time correct';
    ok $timings->{pausable} >= .001, 'pausable time greater than .001';
    ok $timings->{pausable} <= .02, 'pausable time less than .02';
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
    ok $timings->{'pausable'} >= .001, 'double continue did not blow up';
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
    ok $timings->{overall} >= .005, 'overall time greater than .005';
    ok $timings->{pausable} >= .004, 'pausable time greater than .004';
    ok $timings->{pausable} <= .05, 'pausable time less than .05';
}
