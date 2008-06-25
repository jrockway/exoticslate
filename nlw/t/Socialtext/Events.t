#!perl
# @COPYRIGHT@
use warnings FATAL => 'all';
use strict;
use Test::More qw/no_plan/;
use mocked 'Socialtext::User';
use mocked 'Socialtext::SQL';

BEGIN {
    use_ok('Socialtext::Events');
}

Record_empty_event: {
    eval { Socialtext::Events->Record() };
    like $@, qr/Requires Event parameter/;
}

Getting_events: {
    Get_no_events: {
        my $events = Socialtext::Events->Get();
        isa_ok $events, 'ARRAY';
        is @$events, 0, 'no events found';
        sql_ok( 
            sql => "SELECT * FROM event",
            args => [],
        );
    }

    Get_some_events: {
        my @event = ( '2008-06-25 11:39:21.509539-07', 
                      qw/View 1 Page hello_world/, '' );
        local @Socialtext::SQL::RETURN_VALUES = ( { return => [ \@event ] } );
        my $events = Socialtext::Events->Get();
        is_deeply $events, [ \@event ], 'found event';

        sql_ok( 
            sql => "SELECT * FROM event",
            args => [],
        );
    }

    Get_limited_events: {
        Socialtext::Events->Get( limit => 5 );
        sql_ok( 
            sql => "SELECT * FROM event LIMIT ?",
            args => ['5'],
        );
    }

    Get_before_events: {
        Socialtext::Events->Get( before => 'now' );
        sql_ok( 
            sql => "SELECT * FROM event WHERE timestamp < '?'::timestamptz",
            args => ['now'],
        );
    }

    Get_after_events: {
        Socialtext::Events->Get( after => 'now' );
        sql_ok( 
            sql => "SELECT * FROM event WHERE timestamp > '?'::timestamptz",
            args => ['now'],
        );
    }

    Get_before_and_after: {
        # If both before and after, before wins
        Socialtext::Events->Get( before => 'then', after => 'now' );
        sql_ok( 
            sql => "SELECT * FROM event WHERE timestamp < '?'::timestamptz",
            args => ['then'],
        );
    }

    Get_action_events: {
        Socialtext::Events->Get( action => 'View' );
        sql_ok( 
            sql => "SELECT * FROM event WHERE action = ?",
            args => ['View'],
        );
    }

    Get_action_and_before_events: {
        Socialtext::Events->Get( action => 'View', before => 'then' );
        sql_ok( 
            sql => "SELECT * FROM event WHERE timestamp < '?'::timestamptz "
                   . "AND action = ?",
            args => ['then', 'View'],
        );
    }

    Get_action_and_before_events_with_count: {
        # count and limit are synonyms
        Socialtext::Events->Get(action => 'View', before => 'then', count => 5);
        sql_ok( 
            sql => "SELECT * FROM event WHERE timestamp < '?'::timestamptz "
                   . "AND action = ? LIMIT ?",
            args => ['then', 'View', 5],
        );
    }
}

Creating_events: {
    Record_valid_event: {
        Socialtext::Events->Record( {
            action => 'View',
            actor => 1,
            class => 'Page',
            object => 'hello_world',
        } );
        sql_ok(
            sql => qr/^INSERT INTO event VALUES/,
            args => [ 'now', 'View', 1, 'Page', 'hello_world', '' ],
        );
    }

    Record_valid_event_with_context: {
        Socialtext::Events->Record( {
            action => 'View',
            actor => 1,
            class => 'Page',
            object => 'hello_world',
            context => { foo => 'bar' },
        } );
        sql_ok(
            sql => qr/^INSERT INTO event VALUES/,
            args => [ 
                'now', 'View', 1, 'Page', 'hello_world', '{"foo":"bar"}',
            ],
        );
    }

    Record_event_missing_params: {
        my %params = (
            action => 'foo', actor => 1, class => 'Page', object => 'page title',
        );
        for my $field (qw/action actor class object/) {
            my %p = %params;
            delete $p{$field};
            eval { Socialtext::Events->Record(\%p) };
            like $@, qr/\Q$field\E parameter is missing/;
        }
    }

    Record_event_specified_timestamp: {
        Socialtext::Events->Record( {
            timestamp => 'yesterday',
            action => 'View',
            actor => 1,
            class => 'Page',
            object => 'hello_world',
        } );
        sql_ok(
            sql => qr/^INSERT INTO event VALUES/,
            args => [ 'yesterday', 'View', 1, 'Page', 'hello_world', '' ],
        );
    }

    Record_event_with_user_object: {
        Socialtext::Events->Record( {
            action => 'View',
            actor => Socialtext::User->new( user_id => 42 ),
            class => 'Page',
            object => 'hello_world',
        } );
        sql_ok(
            sql => qr/^INSERT INTO event VALUES/,
            args => [ 'now', 'View', 42, 'Page', 'hello_world', '' ],
        );
    }
}

exit;

sub sql_ok {
    my %p = @_;

    my $sql = shift @Socialtext::SQL::SQL;
    if ($p{sql}) {
        if (ref($p{sql})) {
            like $sql->{sql}, $p{sql}, 'SQL matches';
        }
        else {
            $sql->{sql} =~ s/\s+/ /sg;
            $sql->{sql} =~ s/\s*$//;
            is $sql->{sql}, $p{sql}, 'SQL matches exactly';
        }
    }

    if ($p{args}) {
        is_deeply $sql->{args}, $p{args}, 'SQL args match';
    }
}
