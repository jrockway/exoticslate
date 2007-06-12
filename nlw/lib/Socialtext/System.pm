# @COPYRIGHT@
package Socialtext::System;
use strict;
use warnings;

use base 'Exporter';
our @EXPORT = qw'ipc_run backtick shell_run quote_args';

our $SILENT_RUN = 0;

use IPC::Run ();


sub ipc_run {
    return IPC::Run::run(@_);
}

# like qx()'s, but use the safe, non-shell-interpolated call
sub backtick {
    $@ = 0;
    my $out;
    my $err;
    eval {
        # IPC::Run::run returns true on success
        # STDIN  needs to be closed explicitly
        my $return = ipc_run(\@_, \undef, \$out, \$err);
        die $err unless $return;
    };
    return $out;
}

sub shell_run {
    my @args = @_;
    
    my $no_die = $args[0] =~ s/^-//;
    if (@args == 1) {
        print "$args[0]\n" unless $SILENT_RUN;
    }
    else {
        print quote_args(@args) . "\n" unless $SILENT_RUN;
    }

    my $rc = system(@args);
    return if $no_die or $rc == 0;

    if ($? == -1) {
       die "@args: failed to execute: $!\n";
    }
    elsif ($? & 127) {
       die sprintf "@args: child died with signal %d, %s coredump\n",
           ($? & 127),  ($? & 128) ? 'with' : 'without';
    }
    die sprintf "@args: child exited with value %d\n", $? >> 8;
}

sub quote_args {
    for (@_) {
        if ($_ eq '') {
            $_ = q{""};
        }
        elsif ( m/[^\w\.\-\_]/ ) {
            s/([\\\$\'\"])/\\$1/g;
            $_ = qq{"$_"} if /\s/;
        }
    }
    return join ' ', @_;
}

1;
