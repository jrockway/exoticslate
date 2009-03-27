package Socialtext::Job::Test;
use strict;
use warnings;
use base qw( TheSchwartz::Worker );
use Socialtext::Log 'st_log';
use Time::HiRes qw/sleep/;

our $Work_count = 0;

sub work {
    my $class = shift;
    my TheSchwartz::Job $job = shift;
    my $args = $job->arg;

    $Work_count++;

    st_log->debug($args->{message})      if $args->{message};
    sleep $args->{sleep}                 if $args->{sleep};
    st_log->debug($args->{post_message}) if $args->{post_message};

    $job->completed();
}

1;
