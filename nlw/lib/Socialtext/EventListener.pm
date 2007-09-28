# @COPYRIGHT@
package Socialtext::EventListener;
use strict;
use warnings;

=head1 NAME

Socialtext::EventListener - Listeners for change events.

=head1 SYNOPSIS

    package Socialtext::EventListener::Page::BlackberryNotifier;

    use base 'Socialtext::EventListener';

    sub react {
        my ( $self, $event ) = @_;

        # ...

        return $self->_run_admin( ... );
    }

=head1 DESCRIPTION

Subclass C<Socialtext::EventListener> in order to listen for page, attachment,
or workspace change events from the Socialtext system via the ceqlotron.

=cut

use Socialtext::AppConfig;
use Socialtext::Log 'st_log';
use POSIX qw( :sys_wait_h :signal_h );
use IPC::Run qw( run );

=head1 OBJECT METHODS

=head2 $listener->react( $event );

Subclasses are expected to implement this method.  See L</SYNOPSIS>.

=cut

# FIXME: This is cut/paste duplication from Socialtext::Search::*.  It'd be
# nice to be able to say:
#
# *react = \&Socialtext::Plugin::_not_implemented;
sub react {
    my ( $self ) = @_;

    if (ref $self) {
        croak(ref $self, ": internal bug: react not implemented");
    }
    else {
        croak(__PACKAGE__, "::react called in a weird way");
    }
}

=head2 $listener->_run_noop();

Run a no-op. The equivalent of `st-admin` with no arguments.

https://www2.socialtext.net/corp/index.cgi/BARF.WAV?action=attachments_download;page_name=gizmo;id=20070522210551-0-17265

=cut

sub _run_noop {
    return shift->_run_admin();
}

=head2 $listener->_run_admin( $workspace_name, @lines );

Each element of C<@lines> is a listref of arguments to be sent on C<STDIN> to
C<st-admin>.  These are equivalent to command-line arguments.  See L<st-admin>
for more details.

=cut
# This either runs st-admin in the foreground (_exec_admin) or background
# (_fork_admin) depending on the value in
# AppConfig->ceqlotron_synchronous.
sub _run_admin {
    my $self = shift;
    Socialtext::AppConfig->ceqlotron_synchronous
        ? _exec_admin( @_ )
        : _fork_admin( @_ );
}

# This runs st-admin asynchronously and sends the approciate commands
# on stdin.  @lists is a list of command+argument lists.
sub _fork_admin {
    my ( $workspace, @lists ) = @_;

    # Note: we need to fork first, then call IPC::Run::run.  Recall that run()
    # works like the system() builtin.  It waits for the child process to
    # exit.  In order to do more than one thing at a time, we have to fork
    # first.

    # Block all incoming signals before fork.
    my $old_sigset = POSIX::SigSet->new;
    my $all_signals = POSIX::SigSet->new;
    $all_signals->fillset;
    unless (defined sigprocmask(SIG_BLOCK, $all_signals, $old_sigset)) {
        st_log->notice( "ST::Ceqlotron SIG_BLOCK: $!" );
        return;
    }
    my $child_pid = fork;

    if (! defined $child_pid) {
        st_log->notice( "ST::Ceqlotron fork failed: $!" );
        goto UNBLOCK_AND_RETURN;
    }
    elsif ($child_pid == 0) { # in child process
        foreach my $signal (keys %SIG) {
            $SIG{$signal} = 'DEFAULT';
        }
        # Now safe to unblock signals.
        sigprocmask(SIG_SETMASK, $old_sigset);
        st_log->debug("ST::Ceqlotron fork pid $$");
        _exec_admin( $workspace, @lists );
        # REVIEW: in the future we will want to exit with the
        # status of the fork.
        exit;
    }

UNBLOCK_AND_RETURN:
    # Unblock signals before returning.
    sigprocmask(SIG_SETMASK, $old_sigset);
}

# This runs st-admin and sends the appropriate commands on stdin.
sub _exec_admin {
    my ( $workspace, @lines ) = @_;
    my $in = join '', map { "$_\n" } map { join "\0", @$_, '--ceqlotron' } @lines;
    my $out;
    my $err;

    my $script = Socialtext::AppConfig->admin_script;
    my @cmd = ( $script, 'from_input' );

    my $run_results = run \@cmd, \$in, \$out, \$err;
    st_log->error("ST::Ceqlotron unable to exec @cmd: $!") unless $run_results;

    _log_output(\@cmd, $out, $err) if $out or $err;

    return $run_results;
}

# borrowed from Socialtext::Postprocess::Runner may it rip
sub _log_output {
    my $command = shift;
    my @output  = @_;

    my $dir = "/tmp/nlw-postprocess-$<";
    -e $dir or mkdir $dir; # we can't output at this point, so silently fail =(

    # the messages produced by this sub are far too noisy to be of
    # value in the syslog, so produce a pointer in the syslog to the
    # more verbose log
    st_log->warning("ST::Ceqlotron @$command produced output in $dir");

    my $name = join('_', @$command);

    # no / or : in file names, otherwise things aren't going to work well
    $name =~ s{/|:}{-}g;

    # In some testing situations this fail to open, but we
    # don't want to die when that happens.
    my $error_log = "$dir/$$-$name";
    if ( open my $fh, '>', $error_log ) {
        print $fh join "---\n", @output;
        close $fh;
    }
    else {
        st_log->warning("ST::Ceqlotron unable to open $error_log for writing: $!");
    }
}

=head1 SEE ALSO

L<Socialtext::EventListener::Page::IndexPage> as a sample implementation,
L<Socialtext::Ceqlotron>,
L<ceqlotron>,
L<Socialtext::ChangeEvent>, and
L<st-admin>.

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
1;
