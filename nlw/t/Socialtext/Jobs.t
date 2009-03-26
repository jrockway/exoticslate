#!/usr/bin/perl
use strict;
use warnings;
use Test::Socialtext qw/no_plan/;
use Socialtext::SQL qw/sql_singlevalue/;

fixtures 'clean';

BEGIN {
    use_ok 'Socialtext::Jobs';
}

# Clean up the schwartz state
sql_singlevalue('truncate job');

Queue_job: {
    my $jorbs = Socialtext::Jobs->new;
    my @jobs = $jorbs->list_jobs(
        funcname => 'TestJob',
    );
    is scalar(@jobs), 0, 'no jobs to start with';

    $jorbs->work_asynchronously( 'TestJob', { test => 1 } );

    @jobs = $jorbs->list_jobs(
        funcname => 'TestJob',
    );
    is scalar(@jobs), 1, 'found a job';
    my $j = shift @jobs;
    is $j->funcname, 'TestJob', 'funcname is correct';

    my $time = sql_singlevalue("select 'now'::timestamptz");
    unlike $time, qr/[+-]0000$/, 'we have a timezone again';
}
