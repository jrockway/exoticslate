package Socialtext::Job::Test;
use strict;
use warnings;
use base qw( TheSchwartz::Worker );

our $Work_count = 0;

sub work {
    my $class = shift;
    my TheSchwartz::Job $job = shift;

    $Work_count++;

    $job->completed();
}

1;
