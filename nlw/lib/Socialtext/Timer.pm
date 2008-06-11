package Socialtext::Timer;
# @COPYRIGHT@
use strict;
use warnings;

use Time::HiRes qw( gettimeofday tv_interval );

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

sub Stop {
    my $class = shift;
    my $timed = shift;
    $Timings->{$timed} = $Timings->{$timed}->elapsed();
}

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->start_timing;
    return $self;
}

sub start_timing {
    my $self = shift;
    $self->{_start_time} = [gettimeofday];
}

sub elapsed {
    my $self = shift;
    return tv_interval($self->{_start_time});
}

1;
