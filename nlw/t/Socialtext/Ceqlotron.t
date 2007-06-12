#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 9;
fixtures( 'admin' );

# Use this file for testing Socialtext::Ceqlotron subs.  Use ceqlotron.t for testing
# bin/ceqlotron from the outside.

use Socialtext::Ceqlotron 'foreach_event';

use Readonly;

my $hub = new_hub('admin');

Readonly my @PAGE_IDS      => qw(
    start_here quick_start project_plans people meeting_agendas
);
Readonly my $SLEEP_SECONDS => 2;

use_ok( 'Socialtext::Ceqlotron' );

# Make sure nothing else is already in the queue
Socialtext::Ceqlotron::clean_queue_directory();
Socialtext::Ceqlotron::ensure_lock_file();

test_lock_is_idempotent();
test_lock_is_exclusive();
test_foreach_ctime();
test_last_event();
test_event_removal();

# This test verifies that the ceqlotron removes events from the queue
# when run synchrously, using the events created elsewhere in this file.
sub test_event_removal {
    my $count;

    _event_count_test(5, "With a fresh queue, ");
    Test::Socialtext::ceqlotron_run_synchronously();
    _event_count_test(0, "After running the queue, ");
}

# This test verifies that foreach_event goes through in CTIME order.
sub test_foreach_ctime {
    my @pages_in_foreach_order;
    create_events();

    foreach_event( sub {
        my ( $event ) = @_;
        if ($event->isa('Socialtext::ChangeEvent::Page')) {
            push @pages_in_foreach_order, $event->page_uri;
        }
        else {
            die "$event is not a page!\n";
        }
    } );

    is_deeply(
        \@pages_in_foreach_order,
        \@PAGE_IDS,
        "foreach_event order respects ctime."
    );
}

sub create_events {
    my $seconds = $SLEEP_SECONDS * @PAGE_IDS;
    Test::More::diag("This will take at least $seconds seconds.");
    foreach my $page_id (@PAGE_IDS) {
        Socialtext::ChangeEvent->Record(
            $hub->pages->new_from_name($page_id)
        );
        sleep $SLEEP_SECONDS;
    }
}

sub test_last_event {
    my $event_count = 0;

    foreach_event( sub { ++$event_count } );

    isnt(
        $event_count, 0,
        "There are events in the queue, so the next test is meaningful."
    );

    $event_count = 0;

    foreach_event( sub {
        ++$event_count;
        Socialtext::Ceqlotron::last_event();
    } );

    is(
        $event_count, 1,
        "last_event() bails us out of the foreach_event() loop."
    );
}

# This test verifies that the lock is exclusive.
sub test_lock_is_exclusive {
    Socialtext::Ceqlotron::acquire_lock() or die "can't get the lock";

    child_acquire_is( 0, "Child cannot get the lock when parent holds it." );

    Socialtext::Ceqlotron::release_lock();

    child_acquire_is( 1, "release_lock allows other process to acquire lock." );
}

sub child_acquire_is {
    my ( $expected_acquire_return, $reason ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $child_pid = fork;
    if (! defined $child_pid) {
        die "fork: $!";
    }
    elsif ($child_pid == 0) { # in child
        exit Socialtext::Ceqlotron::acquire_lock();
    }
    else { # in parent
        die "Could not wait for child: $!" if (waitpid $child_pid, 0) < 1;
        is( ($? >> 8), $expected_acquire_return, $reason );
    }
}

# Verify that we can re-get the lock without any trouble.
sub test_lock_is_idempotent {
    Socialtext::Ceqlotron::acquire_lock() or die "can't get the lock";
    is( Socialtext::Ceqlotron::acquire_lock(), 1, "Okay to get the lock twice." );
}

sub _event_count_test {
    my ( $count_goal, $explanation ) = @_;
    my $count = 0;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    foreach_event( sub { $count++ } );

    is( $count, $count_goal, "${explanation}there are $count_goal events." );
}

