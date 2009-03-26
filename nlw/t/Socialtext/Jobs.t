#!/usr/bin/perl
use strict;
use warnings;
use Test::Socialtext qw/no_plan/;
use Socialtext::SQL qw/sql_singlevalue/;

fixtures 'clean';

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

Time_is_okay: {
    my $time = sql_singlevalue("select 'now'::timestamptz");
    unlike $time, qr/[+-]0000$/, 'we have a timezone again';
}
