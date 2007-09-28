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

use Socialtext;
use Socialtext::ChangeEvent;
use Socialtext::File;
use Socialtext::Log 'st_log';
use Socialtext::Paths;
use Socialtext::EventListener::Registry;

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

# React to events and then unlink afterwards.
sub _dispatch_symlink {
    my ( $event ) = @_;

    my @event_type_parts = split /::/, ref $event;
    my $event_type = $event_type_parts[-1];

    my $forked_children = 0;

    Socialtext::EventListener::Registry->load();
    my $listeners = $Socialtext::EventListener::Registry::Listeners{$event_type};
    foreach my $listener (@$listeners) {
        eval { 
            eval "require $listener";
            $listener->react($event);
        };
        if ($@) {
            st_log->error( "$listener failed with: $@" ); 
        } else {
            $forked_children++;
        }
    }

    if ($forked_children) {
        my $path = $event->link_path;
        unlink $path
            or st_log->error( "ST::Ceqlotron unlinking $path failed: $!" );
    }

    return $forked_children;
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
