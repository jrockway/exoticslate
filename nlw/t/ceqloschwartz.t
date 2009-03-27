#!perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext;
use Test::More qw/no_plan/;
use Time::HiRes;
use Socialtext::System qw/shell_run/;
use Socialtext::Jobs;
use File::LogReader;
use Socialtext::AppConfig;
fixtures( 'db', 'base_config' );

my $NLW_log_file = 't/tmp/log/nlw.log';
shell_run("touch $NLW_log_file");
my $nlwlog = File::LogReader->new( filename => $NLW_log_file );

my $Ceq_bin = 'bin/ceqlotron';
ok -x $Ceq_bin;
Socialtext::Jobs->clear_jobs();

shell_run("st-config set ceqlotron_period 0.1 > /dev/null");
shell_run("st-config set ceqlotron_max_concurrency 5 > /dev/null");

Start_and_stop: {
    while( $nlwlog->read_line ) { } # fast forward to end of the file

    shell_run($Ceq_bin); # should start & daemonize
    like $nlwlog->read_line, qr/ceqlotron starting/, 'ceq logged that it started';

    my $ceq_pid = qx($Ceq_bin --pid); chomp $ceq_pid;
    ok kill(0 => $ceq_pid), "ceq pid $ceq_pid is alive";

    Start_another_ceq: {
        shell_run($Ceq_bin); # should start & daemonize
        my $new_pid = qx($Ceq_bin --pid); chomp $new_pid;
        is $new_pid, $ceq_pid, 'ceq pid did not change';
    }

    while( $nlwlog->read_line ) { } # fast forward to end of the file
    ok kill(INT => $ceq_pid), "sent INT to $ceq_pid";
    sleep 1;
    like $nlwlog->read_line, qr/ceqlotron exiting/, 'ceq logged that it stopped';
    ok !kill(0 => $ceq_pid), "ceq pid $ceq_pid is no longer alive";
}

Process_a_job: {
    shell_run($Ceq_bin); # should start & daemonize
    my $ceq_pid = qx($Ceq_bin --pid); chomp $ceq_pid;

    while( $nlwlog->read_line ) { } # fast forward to end of the file
    Socialtext::Jobs->new->work_asynchronously(
        'Test',
        { 
            message => 'no pun intended',
            sleep => 2,
            post_message => 'twss',
        },
    );

    my $did_it;
    my $tries = 7;
    TRIES: while ($tries > 0) {
        while (my $line = $nlwlog->read_line) {
            if ($line =~ m/no pun intended/) {
                $did_it++;
                last TRIES;
            }
        }
        sleep 1;
        $tries--;
    }
    ok $did_it, 'the message appeared in the logs';

    # Now send the process SIGTERM, and it should start to exit
    while( $nlwlog->read_line ) { }
    ok kill(TERM => $ceq_pid), "sent TERM to $ceq_pid";
    sleep 3;
    like $nlwlog->read_line, qr/caught SIGTERM/;
    like $nlwlog->read_line, qr/waiting for children to exit/;
    like $nlwlog->read_line, qr/twss/;
}


Workers_are_limited: {
    Socialtext::Jobs->new->work_asynchronously(
        'Test',
        { 
            message => "start-$_",
            sleep => 2,
            post_message => "end-$_",
        },
    ) for (0 .. 9);

    while( $nlwlog->read_line ) { } # fast forward to end of the file
    shell_run($Ceq_bin); # should start & daemonize
    my $ceq_pid = qx($Ceq_bin --pid); chomp $ceq_pid;


    sleep 3;
    like $nlwlog->read_line, qr/starting/;
    like $nlwlog->read_line, qr/start-\d/;
    like $nlwlog->read_line, qr/start-\d/;
    like $nlwlog->read_line, qr/start-\d/;
    like $nlwlog->read_line, qr/start-\d/;
    like $nlwlog->read_line, qr/start-\d/;
    like $nlwlog->read_line, qr/end-\d/, 'job ended before sixth job started';

    # Now send the process SIGTERM, and it should start to exit
    ok kill(INT => $ceq_pid), "sent INT to $ceq_pid";
}

exit;

