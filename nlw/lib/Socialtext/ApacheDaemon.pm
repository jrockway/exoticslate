# @COPYRIGHT@
package Socialtext::ApacheDaemon;
use strict;
use warnings;

use Carp;
use Class::Field qw(field);
use File::Basename ();
use Socialtext::File;
use Socialtext::System;
use Readonly;
use Time::HiRes qw( sleep time );
use User::pwent;
use Sys::Hostname;

# Set this if you want some debugging output.
our $Verbose = 0;

field 'conf_file';
field 'name';

# These can all be fractional seconds because we're using Time::HiRes.
Readonly my $SLEEP_SECONDS                    => 0.1;
Readonly my $PATIENT_SECONDS_AFTER_FIRST_KILL => 3;
Readonly my $TOTAL_SECONDS_TO_WAIT            => 25;

Readonly my $BIN_DIR => '/usr/sbin';
Readonly my %BINARY => (
    'apache2'     => 'apache2',
    'apache-perl' => 'apache',
);
Readonly my %ENV_OVERRIDE => (
    'apache2'     => 'NLW_APACHE2_PATH',
    'apache-perl' => 'NLW_APACHE_PATH',
);

sub new {
    my $class = shift;

    my $self = bless {@_}, $class;

    unless ( $self->name ) {
        my ($name) = $self->conf_file =~ m{/etc/([^/]+)/}
            or die "Cannot determine apache name from conf_file: ", $self->conf_file;
        $self->name($name);
    }

    return $self;
}

sub conf_filename {
    return $_[0]->name eq 'apache2' ? 'apache2.conf' : 'httpd.conf';
}

sub start {
    my $self = shift;

    my $httpd_conf = $self->conf_file;
    -e $httpd_conf or die "$httpd_conf doesn't exist!\n";
    return $self->hup
        if $self->is_running;
    if ( -f $self->pid_file ) {
        warn "Looks like we have a stale pid file (removing).\n";
        unlink $self->pid_file;
    }
    $self->kill_server_disrespecting_the_pid_file
      if $self->servers_running_on_this_port;
    $self->actually_start;
    $self->wait_for_startup;
}

sub hup {
    my $self = shift;

    $self->output_action('Hupping');
    my $exists = 1;
    $self->send_signal(
        'HUP',
        on_process_doesnt_exist => sub {
            if ( -f $self->pid_file ) {
                unlink $self->pid_file
                    or warn "Couldn't remove " . $self->pid_file . ": $!";
                $exists = 0;
            }
        },
    );
    $self->start unless $exists;
}

sub stop {
    my $self = shift;

    unless ($self->servers_running_on_this_port) {
        warn 'No ', $self->short_binary, " servers to stop.\n";
        return;
    }
    $self->output_action('Stopping');
    $self->try_killing;
    my $start_time = time;
    while ( -f $self->pid_file ) {
        sleep $SLEEP_SECONDS;
        my $elapsed_time = time - $start_time;
        $self->try_killing
            if $elapsed_time > $PATIENT_SECONDS_AFTER_FIRST_KILL;
        die $self->pid_file, " - file still exists after ",
            "$TOTAL_SECONDS_TO_WAIT seconds.  Exiting."
            if $elapsed_time > $TOTAL_SECONDS_TO_WAIT;
    }
    $self->kill_server_disrespecting_the_pid_file
      if $self->servers_running_on_this_port;
}

sub try_killing {
    my $self = shift;

    $self->send_signal(
        'TERM',
        on_process_doesnt_exist => sub {
            if ( -f $self->pid_file ) {
                unlink $self->pid_file
                    or warn "Couldn't remove " . $self->pid_file . ": $!";
            }
        }
    );
}

# Note: this is somewhat of an anachronism, now that we send signal's to
# processes other than the one listed in the pid file.
sub send_signal {
    my $self = shift;

    my $signal = shift;
    my %args   = @_;
    return unless $self->pid;
    my $result = kill $signal, $self->pid;
    $args{on_process_doesnt_exist}->()
        if ! $result and $! =~ /no such (?:file|proc)/i;
    return $result;
}

# this is the sub that makes send_signal's generic name incorrect.
sub kill_server_disrespecting_the_pid_file {
    my $self = shift;

    my @pids = $self->servers_running_on_this_port;
    warn "Killing server(s) [@pids] running with our config, but without a pid file.\n";
    return unless @pids;
    kill 2, @pids
      or die $!;
    $self->wait_for_servers_to_quit
      and return;
    $self->kill_dash_nine_all_has_failed;
}

sub kill_dash_nine_all_has_failed {
    my $self = shift;

    my @pids = $self->servers_running_on_this_port;
    warn "Timed out waiting for pids (@pids) to let go.  kill -9'ing!\n";
    kill 9, @pids
      or warn $!;
    return
      if $self->wait_for_servers_to_quit;
    warn "That didn't even work.  Ryan's code sucks.\n";
}

sub wait_for_servers_to_quit {
    my $self = shift;

    my $x = 0;
    until ($x++ >= (20 / $SLEEP_SECONDS)) {
        sleep $SLEEP_SECONDS;
        return 1 unless $self->servers_running_on_this_port;
    }
    return;
}

sub actually_start {
    my $self = shift;

    my @command = $self->get_start_command;
    my @ports = $self->ports;
    $self->output_action('Starting');
    eval { $self->try_system(@command); };
    if ($@) {
        die 'Cannot start ', $self->short_binary, " with @command.\n",
            $self->error_log, "\n";
    }
    $self->maybe_test_verbose("\nStarting ", $self->short_binary, " .\n");
}

sub try_system {
    my $self = shift;

    warn "exec: @_\n" if $Verbose;

    if (system(@_) != 0) {
        Carp::confess "exec @_ exited nonzero: $?";
    }
}

sub wait_for_startup {
    my $self = shift;

    my $x = 0;
    until ( -f $self->pid_file ) {
        sleep $SLEEP_SECONDS;
        $self->maybe_test_verbose('.');
        if ( $x++ == 60 ) {
            $ENV{NLW_TESTS_DIRTY} = 1;
            die 'Timed out after ' . $x * $SLEEP_SECONDS .  ' seconds while waiting for: '
                . $self->pid_file . "\n"
                . "(Left t/tmp/* intact so you can inspect the aftermath)\n";
        }
    }
    $self->maybe_test_verbose("\n", $self->short_binary, "started\n");
}

sub maybe_warn {
    my $self = shift;

    print STDERR @_ if
        $Verbose
        || (
            ! $ENV{NLWCTL_QUIET}
            && ( $ENV{TEST_VERBOSE} || ! $ENV{HARNESS_ACTIVE} )
        )
}

sub maybe_test_verbose {
    print STDERR @_ if $Verbose || $ENV{NLW_TEST_VERBOSE};
}

sub output_urls {
    my $self = shift;
    $self->maybe_warn(" URL: " . $self->base_url(0) . "\n");
    $self->maybe_warn(" URL: " . $self->base_url(1) . "\n");
}

sub base_url {
    my ( $self, $ssl ) = @_;
    $ssl = $ssl ? 1 : 0;
    my $hostname = Sys::Hostname::hostname();
    my $proto = $ssl ? 'https' : 'http';
    my $port = ($self->ports)[$ssl];
    return "$proto://$hostname:$port/";
}

sub output_action {
    my $self = shift;

    my $doing = shift;
    my @ports = $self->ports;
    $self->maybe_warn("$doing ", $self->short_binary, " on ports: @ports\n");
}

sub binary {
    my $self = shift;

    return $self->_binary_override || $self->_binary_default;
}

sub _binary_override {
    my $self = shift;

    my $override = $ENV{$ENV_OVERRIDE{ $self->name }};

    return $override ? $override : '';
}

sub _binary_default {
    my $self = shift;

    return join '/', $BIN_DIR, $BINARY{ $self->name };
}

sub short_binary { return File::Basename::basename( $_[0]->binary ) }

sub get_start_command { return ($_[0]->binary, '-f', $_[0]->conf_file) }

sub ports {
    my $self = shift;

    my %ports = map {
        $_ => 1
    } grep {
        defined $_
    } map {
        /^\s*(?:Listen|Port)\s+(?:[\d\.]*:)?(\d+)/
            ? $1
            : undef
    } Socialtext::File::get_contents( $self->conf_file );
    return sort keys %ports;
}

sub error_log { return $_[0]->log('ErrorLog'); }

sub access_log { return $_[0]->log('CustomLog'); }

sub log {
    my $self = shift;

    my $which = shift;
    die unless defined $which;
    my $log = Socialtext::File::get_contents( $self->parse_from_config_file($which) );
    # Strip irritating prefix stuff:
    $log =~ s/\[\w+\s+\w+\s+\d+\s+\d{2}:\d{2}:\d{2} \d{4}\] \S+://g;
    return $log;
}

sub blank_log_files {
    my $self = shift;

    for (qw'ErrorLog CustomLog') {
        my $filename = $self->parse_from_config_file($_);
        next unless -f $filename;
        open my $fh, '>', $filename;
    }
}

sub pid {
    my $self = shift;

    return unless -f $self->pid_file;
    eval {
       chomp(my $pid = Socialtext::File::get_contents( $self->pid_file ));
       return $pid;
    };
}

sub pid_file {
    return $_[0]->parse_from_config_file('PidFile');
}

sub is_running {
    my $self = shift;

    return -f $self->pid_file and kill 0, $self->pid;
}

sub servers_running_on_this_port {
    my $self = shift;

    my @ports = $self->ports;
    my @lsof = map {
        # COMMAND   PID  USER   FD   TYPE   DEVICE SIZE NODE NAME
        # apache  12713 rking   16u  IPv4 75237577       TCP *:31008 (LISTEN)
        my @bits = split /\s+/;
        my $node = $bits[7];
        $node = $bits[8] if $node eq 'TCP'; # Hack for OS X output.
        $node =~ s/.+://;
        {
            command => $bits[0],
            pid => $bits[1],
            user => $bits[2],
            port => $node,
        }
    } split /\n/, backtick(qw(lsof -i -n));
    shift @lsof;
    my $username = getpwuid($<)->name;
    return map {
        warn "Weird - $_->{command} $_->{pid} isn't owned by $username\n"
            if $_->{user} ne $username;
        $_->{pid}
    } grep {
        my $found_port = 0;
        for my $port (@ports) {
            $found_port = 1
              if $_->{port} eq $port
        }
        $found_port
    } grep {
        ($_->{command} eq $self->short_binary || $_->{command} eq 'httpd')
    } @lsof
}

sub parse_from_config_file {
    my $self = shift;

    my $looking_for = shift;
    Socialtext::File::get_contents( $self->conf_file ) =~ /^$looking_for\s*(\S+)/m
        or die "Couldn't find $looking_for in " . $self->conf_file;
    return $1;
}

1;

