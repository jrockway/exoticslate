#!/usr/bin/perl
use strict;
use warnings;
use Test::Socialtext qw/no_plan/;
use Socialtext::SQL qw/sql_singlevalue/;

fixtures 'db';

BEGIN {
    use_ok 'Socialtext::Jobs';
    use_ok 'Socialtext::Job::Test';
}

my $jobs = Socialtext::Jobs->new;
$jobs->clear_jobs();

Queue_job: {
    my @jobs = $jobs->list_jobs(
        funcname => 'Test',
    );
    is scalar(@jobs), 0, 'no jobs to start with';

    $jobs->work_asynchronously( 'Test', test => 1 );

    @jobs = $jobs->list_jobs(
        funcname => 'Test',
    );
    is scalar(@jobs), 1, 'found a job';
    my $j = shift @jobs;
    is $j->funcname, 'Socialtext::Job::Test', 'funcname is correct';

    $jobs->clear_jobs();
    is scalar(@jobs), 0, 'no jobs to start with';
}

Process_a_job: {
    $jobs->work_asynchronously( 'Test', test => 1 );
    is scalar($jobs->list_jobs( funcname => 'Test' )), 1;
    is $Socialtext::Job::Test::Work_count, 0;
   
    $jobs->schwartz_run( can_do => 'Socialtext::Job::Test' );
    $jobs->schwartz_run( 'work_once' );

    is scalar($jobs->list_jobs( funcname => 'Test' )), 0;
    is $Socialtext::Job::Test::Work_count, 1;
}

Time_is_okay: {
    my $time = sql_singlevalue("select 'now'::timestamptz");
    unlike $time, qr/[+-]0000$/, 'we have a timezone again';
}
