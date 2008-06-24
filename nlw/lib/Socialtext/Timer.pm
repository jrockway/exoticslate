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
        if (ref($Timings->{$timer})) {
            $class->Stop($timer);
        }
    }
    return {map {$_ => $Timings->{$_}} keys(%$Timings)}
}

sub Start {
    my $class = shift;
    my $timed = shift;
    $Timings->{$timed} = $class->new();
}

sub Pause {
    my $class = shift;
    my $timed = shift;
    if (ref($Timings->{$timed})) {
        $class->Stop($timed);
    }
    else {
        # FIXME: make the Timer reentrant
        $Timings->{$timed} = 'reentered';
    }
}

sub Continue {
    my $class = shift;
    my $timed = shift;
    if ($Timings->{$timed}) {
        if (ref($Timings->{$timed})) {
            $class->Stop($timed);
        }
        # FIXME: make the Timer reentrant
        unless ($Timings->{$timed} eq 'reentered') {
            $Timings->{$timed} = $class->new($Timings->{$timed});
        }
    }
    else {
        $class->Start($timed);
    }
}

sub Stop {
    my $class = shift;
    my $timed = shift;
    $Timings->{$timed} = $Timings->{$timed}->elapsed();
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
