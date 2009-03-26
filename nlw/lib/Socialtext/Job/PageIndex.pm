package Socialtext::Job::PageIndex;
use strict;
use warnings;
use base qw( TheSchwartz::Worker );

sub work {
    my $class = shift;
    my TheSchwartz::Job $job = shift;

    $job->completed();
}

1;
