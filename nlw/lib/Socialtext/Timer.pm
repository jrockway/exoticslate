package Socialtext::Timer;
# @COPYRIGHT@
use strict;
use warnings;

use Time::HiRes qw( time );

our $Timings = {};

sub Reset {
    my $class = shift;
    $Timings = {};
    $class->Start('overall');
}

sub Report {
    my $class = shift;
    foreach my $timer (keys(%$Timings)) {
        if (ref($Timings->{$timer}->{timer})) {
            $class->Stop($timer);
        }
    }
    return {map {$_ => sprintf('%0.03f', $Timings->{$_}->{timer})} keys(%$Timings)}
}

sub Start {
    my $class = shift;
    my $timed = shift;
    $Timings->{$timed}->{counter}++;
    $Timings->{$timed}->{timer} = $class->new();
}

sub Pause {
    my $class = shift;
    my $timed = shift;
    if (ref($Timings->{$timed}->{timer}) && $Timings->{$timed}->{counter} <= 1) {
        $Timings->{$timed}->{counter}--;
        $class->Stop($timed);
    }
}

sub Continue {
    my $class = shift;
    my $timed = shift;
    if (ref($Timings->{$timed}->{timer})) {
        $class->Stop($timed);
    }
    $Timings->{$timed}->{counter}++;
    $Timings->{$timed}->{timer} = $class->new($Timings->{$timed}->{timer});
}

sub Stop {
    my $class = shift;
    my $timed = shift;
    $Timings->{$timed}->{timer} = $Timings->{$timed}->{timer}->elapsed();
}

sub new {
    my $class = shift;
    my $start_offset = shift || 0;
    my $self = {};
    bless $self, $class;
    $self->start_timing($start_offset);
    return $self;
}

sub start_timing {
    my $self = shift;
    my $offset = shift;
    $self->{_start_time} = time - $offset;
}

sub elapsed {
    my $self = shift;
    return time - $self->{_start_time};
}

1;
