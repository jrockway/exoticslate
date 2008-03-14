package Socialtext::Timer;
# @COPYRIGHT@
use strict;
use warnings;

use Time::HiRes qw( gettimeofday tv_interval );

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
