# @COPYRIGHT@
package Socialtext::Ceqlotron;

use strict;
use warnings;

use base 'Exporter';

use Errno (); # makes %! work
use Fcntl ':flock';
use POSIX qw( :sys_wait_h :signal_h );
use IPC::Run qw( run );
use Readonly;

use Socialtext::ChangeEvent;
use Socialtext::File;
use Socialtext::Log 'st_log';
use Socialtext::Paths;

our @EXPORT_OK = qw( foreach_event );

Readonly my $QUEUE_DIR  => Socialtext::Paths::change_event_queue_dir();
Readonly my $QUEUE_LOCK => Socialtext::Paths::change_event_queue_lock();

# XXX refactor path comparison logic to Socialtext::Paths or Socialtext::Page
Readonly my $DATA_DIR         => Socialtext::AppConfig->data_root_dir;
Readonly my $PAGE_REGEX       => qr{^\Q$DATA_DIR\E/data/(.*?)/(.*)};
Readonly my $ATTACHMENT_REGEX =>
    qr{^\Q$DATA_DIR\E/plugin/(.*?)/attachments/(.*?)/(.*?)/};
Readonly my $WORKSPACE_REGEX => qr{^\Q$DATA_DIR\E/data/([^/]+)/?$};

my $Last_event = 0;
my $Lock_fh;

=head1 SUBROUTINES

=head2 run_current_queue()

Performs all jobs for all change events in the queue.  warn()s and then
returns if it is unable to acquire the lock.

You probably want to ensure that L<Socialtext::AppConfig/ceqlotron_synchronous> is
set to 1 if you use this, so that the queue is actually run when the
subroutine returns.

=cut

sub run_current_queue {
    ensure_queue_directory();
    ensure_lock_file();
    unless (acquire_lock()) {
        warn "unable to run queue\n";
        return;
    }
    examine_symlinks_and_dispatch();
    release_lock();
}

=head2 ensure_queue_directory

Makes sure that the change event queue directory exists on the filesystem.
This method is concurrency-safe, so multiple processes can call it without
worry.  One of them will create the directory first, and the rest will B<see>
that directory.

=cut

sub ensure_queue_directory {
    Socialtext::File::ensure_directory($QUEUE_DIR);
}

=head2 clean_queue_directory()

Removes all change events from the queue.  CAUTION: This should probably only
be used with tests.

=cut

sub clean_queue_directory {
    if ( -d $QUEUE_DIR ) {
        opendir my $dh, $QUEUE_DIR or die "opendir '$QUEUE_DIR': $!";
        unlink( map {"$QUEUE_DIR/$_"} grep { !/^(?:\.|\.\.)$/ } readdir $dh );
    }
}

=head2 acquire_lock

Attempts to acquire the lock on the change event queue.  This lock is only for
mutual exclusion of those trying to remove events from the queue.  Injecting
events into the queue is lock-free.

=cut

sub acquire_lock {
    my ( $should_block ) = @_;

    st_log->debug( "ST::Ceqlotron trying to get lock"
            . ( $should_block ? " - blocking " : " - non-blocking" ) );

    my $flags = LOCK_EX | ($should_block ? 0 : LOCK_NB);

    open $Lock_fh, '<', $QUEUE_LOCK or die "Open '$QUEUE_LOCK': $!";
    my $got_the_lock = flock $Lock_fh, $flags;

    return 1 if $got_the_lock;

    return 0 if $!{EWOULDBLOCK} or not $!;

    die "flock '$QUEUE_LOCK': $!";
}

=head2 release_lock

Releases the write lock on the change event queue.

=cut

sub release_lock {
    close $Lock_fh if defined $Lock_fh;
}

=head2 ensure_lock_file

Ensures that the lock file exists on disk.  If another process is racing to
create the lock file at the same time, only one will win, but both processes
can then see and use the same lock file.

=cut

sub ensure_lock_file {
    Socialtext::File::ensure_empty_file( $QUEUE_LOCK, "$QUEUE_LOCK-$$" );
}

=head2 examine_symlinks_and_dispatch

Assumes the caller already holds the lock.  Examines the symlinks in
the change event queue and dispatches commands to C<st-admin> based
upon their type.

=cut

sub examine_symlinks_and_dispatch {
    st_log->debug('ST::Ceqlotron entering dispatch loop');
    foreach_event( \&_dispatch_symlink, sub {
        my ( $link, $exception ) = @_;

        if ($exception =~ /(cequnklink \S+ \S+)/) {
            st_log->error("ST::Ceqlotron $1");
        }
        elsif ($exception =~ /readlink/) {
            st_log->error("ST::Ceqlotron found symlink to nonexistent path $link");
        }
        else {
            st_log->error("ST::Ceqlotron got an unknown exception for $link: $exception");
        }
    });
}

=head2 foreach_event( \&event_code [, \&catcher] )

Examines the events in the change event queue and calls

    event_code($event);

on each of them.  If there is an exception and catcher was passed, then

    catcher($link, $@);

is called .  C<$event> is an L<Socialtext::ChangeEvent> subclass.  C<$link> is the
path to the symlink in the change event queue.

In the event you would like to bail out of the 'foreach' loop early, as one
would with Perl's C<last> statement, you can call
C<Socialtext::Ceqlotron::last_event()> from within C<event_code> or C<catcher>, and
when your subroutine exits, it will be the last time through the loop.

=cut

sub foreach_event {
    my ( $code, $catcher ) = @_;
    my @links;
    my $dh;

    unless (opendir $dh, $QUEUE_DIR) {
        st_log->notice("ST::Ceqlotron opendir '$QUEUE_DIR' failed: $!");
        return;
    }

    while (my $entry = readdir $dh) {
        my $path = "$QUEUE_DIR/$entry";

        push @links, $path if -l $path;
    }
    closedir $dh;

    # It would be nice to do a sorted insert up there instead of sort the
    # whole list down here.  Any CPAN module to do that?
    foreach my $link (_by_ctime_and_workspace(\@links)) {
        eval { $code->(Socialtext::ChangeEvent->new($link)) };
        if ($@) {
            if (defined $catcher) {
                $catcher->($link, $@);
            }
            else {
                die $@;
            }
        }
        if ($Last_event) {
            $Last_event = 0;
            return;
        }
    }
}

=head2 last_event

See L</foreach_event>.

=cut

sub last_event { $Last_event = 1 }

=head2 _by_ctime_and_workspace( \@symlinks )

Returns I<@symlinks> in date order, but distributed across workspaces
so that no one workspace gets to pig all the resources.

Here's a list of workspace events 

    foo1
    foo2
    foo3
    foo4                    baz4
    foo5    bar5
    foo6                    baz6
    foo7    bar7    bat7    baz7
                    bat8

where the digit after each workspace name is its time in rank order.
If we only sorted by time order, foo would get 4 of the first 5 slots,
because the list would look like.  That's not fair to the other guys.

Instead, we take the most recent entry from the top of each workspace's
stack of events.  It comes out being done in this order, moving left to
right, top to bottom.

    foo1    bar5    bat7    baz4
    foo2    bar7    bat8    baz6
    foo3                    baz7
    foo4
    foo5
    foo6
    foo7

This list is now ready to be acted on in L<foreach_event>.

Note that the order of the workspaces is not deterministic, because
we're using a hash.  That's not a problem here.

=cut

sub _by_ctime_and_workspace {
    my $links = shift;

    my %queues_by_ctime;

    # Accumulate all the symlinks by workspace.
    foreach my $link (@$links) {
        my $workspace = Socialtext::ChangeEvent->new($link)->workspace_name;
        my $ctime = (lstat($link))[10];

        # Another process may have already disposed of the link, so
        # don't bother pushing it.
        if ( $ctime ) {
            # Stash the link and the time
            push @{$queues_by_ctime{$workspace}}, [$link,$ctime];
        }
    }

    # Sort each workspace's symlinks
    foreach my $workspace ( keys %queues_by_ctime ) {
        $queues_by_ctime{$workspace} = [
            map { $_->[0] }                 # Stash only the link name...
            sort { $a->[1] <=> $b->[1] }    # ... after sorting on ctime
            @{ $queues_by_ctime{$workspace} }
        ];
    }

    # Scrape off the top link from each workspace's queue.
    my @sorted_links;
    while (scalar keys %queues_by_ctime) {
        foreach my $workspace ( keys %queues_by_ctime ) {
            if ( @{$queues_by_ctime{$workspace}} ) {
                push @sorted_links, shift @{$queues_by_ctime{$workspace}};
            }
            else {
                delete $queues_by_ctime{$workspace};
            }
        }
    }

    return @sorted_links;
}

# Given an event, runs st-admin with the correct args and then unlinks
# the event.
sub _dispatch_symlink {
    my ( $event ) = @_;

    my $ran_it = _run_admin(
        $event->workspace_name,
          $event->isa('Socialtext::ChangeEvent::Workspace') ? _workspace_args($event)
        : $event->isa('Socialtext::ChangeEvent::Page')      ? _page_args($event)
        : _attachment_args($event)
    );

    if ($ran_it) {
        my $path = $event->link_path;
        unlink $path
            or st_log->error( "ST::Ceqlotron unlinking $path failed: $!" );
    }
}

sub _workspace_args {
    my ( $event ) = @_;

    st_log->info( 'ST::Ceqlotron workspace event for ' . $event->workspace_name );

    return ( [ 'index-workspace', '--workspace', $event->workspace_name ] );
}

sub _page_args {
    my ( $event ) = @_;

    st_log->info(
        'ST::Ceqlotron page event for ' . $event->workspace_name . ' ' . $event->page_uri );

    return
        map { [ $_, '--workspace', $event->workspace_name, '--page', $event->page_uri ] }
            qw(send-weblog-pings send-email-notifications send-watchlist-emails index-page);
}

sub _attachment_args {
    my ( $event ) = @_;

    st_log->info( 'ST::Ceqlotron attachment event for '
            . $event->workspace_name . ' '
            . $event->page_uri . ' '
            . $event->attachment_id );

    return ( [ 'index-attachment',
               '--attachment', $event->attachment_id,
               '--page', $event->page_uri,
               '--workspace', $event->workspace_name,
             ] );
}

# This either runs st-admin in the foreground (_exec_admin) or background
# (_fork_admin) depending on the value in
# AppConfig->ceqlotron_synchronous.
sub _run_admin {
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
        # flock() locks are inherited by child processes.  We must release the
        # lock here or else we'll hold the lock from the parent until _we_
        # exit.
        release_lock();
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

=head1 APPCONFIG VARIABLES

=head2 ceqlotron_synchronous

If TRUE, C<run_current_queue> and C<examine_symlinks_and_dispatch>
will dispatch tasks from the ceqlotron queue synchronously.  That is,
when each method returns, the caller can be sure that all tasks have
been completed.

=head1 SEE ALSO

L<Socialtext::AppConfig>, L<Socialtext::ChangeEvent>

=cut

1;
