package Socialtext::Events;
# @COPYRIGHT@
use warnings;
use strict;
use Socialtext::Events::Recorder;
use Socialtext::Events::Reporter;

sub Get {
    my $class = shift;
    return Socialtext::Events::Reporter->new->get_events(@_);
}

sub Record {
    my $class = shift;
    my $recorder = Socialtext::Events::Recorder->new;
    return $recorder->record_event(@_);
}

1;
