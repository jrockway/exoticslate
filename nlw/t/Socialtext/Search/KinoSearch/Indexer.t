#!perl
# @COPYRIGHT@
# -*- coding: utf-8 -*- vim:fileencoding=utf-8:
use utf8;
use strict;
use warnings;

use Test::Socialtext tests => 14;
fixtures( 'admin_no_pages' );

BEGIN {
    use_ok("Socialtext::Search::KinoSearch::Indexer");
    use_ok("Socialtext::Search::KinoSearch::Factory");
}

our $WAIT_TIME = 10;

# Test Locking
TEST_LOCK_HANDLING: {
    my $idx1 = make_indexer();
    ok( defined($idx1), "Created Socialtext indexer" );
    $idx1->_init_indexer();
    ok( defined( $idx1->indexer ), "Created KinoSearch indexer" );

    my $idx2 = make_indexer();
    ok( defined($idx2), "Created Socialtext indexer" );

    warn_wait();
    my $err;
DO_TIMED_CODE: {
        local $SIG{ALRM} = sub { die "gave up waiting!\n" };
        alarm($WAIT_TIME);
        eval {
            eval { $idx2->_init_indexer() };
            alarm(0);
            $err = $@;
        };
        my $outer_err = $@;
        is( $outer_err, "", "No error intimed section" ) or diag($outer_err);
    }
    ok(
        not( defined( $idx2->indexer ) ),
        "Failed to create second indexer."
    );
    like(
        $err, qr/gave up waiting!/,
        "Failed get lock for second indexer."
    );
}

ENSURE_SEARCHING_NOT_BLOCKED_BY_INDEX_LOCK: {
    my $idx1 = make_indexer();
    ok( defined($idx1), "Created Socialtext indexer" );
    $idx1->_init_indexer();
    ok( defined( $idx1->indexer ), "Created KinoSearch indexer" );

    warn_wait();
    my $srch = make_searcher();
    ok( defined($srch), "Created Socialtext searcher" );

    my @results;
    my $err;
    DO_TIMED_CODE: {
        local $SIG{ALRM} = sub { die "gave up waiting!\n" };
        alarm($WAIT_TIME);
        eval {
            eval { @results = $srch->search("cows"); };
            alarm(0);
            $err = $@;
        };
        my $outer_err = $@;
        is( $outer_err, "", "No error intimed section" ) or diag($outer_err);
    }
    is( $err, "", "No error searching" ) or diag($err);
    is( scalar(@results), 0, "Got search no results on empty index" );
}

sub make_indexer {
    Socialtext::Search::KinoSearch::Factory->create_indexer('admin');
}

sub make_searcher {
    Socialtext::Search::KinoSearch::Factory->create_searcher('admin');
}

sub warn_wait {
    diag("This could take up to $WAIT_TIME seconds\n");
}
