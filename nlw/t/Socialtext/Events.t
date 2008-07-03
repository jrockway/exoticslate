#!perl
# @COPYRIGHT@
use warnings FATAL => 'all';
use strict;
use Test::More qw/no_plan/;
use mocked 'Socialtext::User';
use mocked 'Socialtext::SQL', 'sql_ok';

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
        my %event = ( 
            timestamp => '2008-06-25 11:39:21.509539-07', 
            action => 'view_page',
            actor => 1,
            object => 'hello_world',
            context => '',
        );
        local @Socialtext::SQL::RETURN_VALUES = ( { return => [ \%event ] } );
        my $events = Socialtext::Events->Get();
        is_deeply $events, [ \%event ], 'found event';

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

    Get_offset_events: {
        Socialtext::Events->Get( offset => 5 );
        sql_ok( 
            sql => "SELECT * FROM event OFFSET ?",
            args => ['5'],
        );
    }

    Get_limit_and_offset_events: {
        Socialtext::Events->Get( limit => 5, offset => 10 );
        sql_ok( 
            sql => "SELECT * FROM event LIMIT ? OFFSET ?",
            args => ['5', '10'],
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

    Get_action_events_for_class: {
        Socialtext::Events->Get( action => 'View', class => 'thingers' );
        sql_ok( 
            sql => "SELECT * FROM event WHERE class = ? AND action = ?",
            args => ['thingers', 'View'],
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
        Socialtext::Events->Get(action => 'view', before => 'then', count => 5);
        sql_ok( 
            name => 'Get_action_and_before_events_with_count',
            sql => "SELECT * FROM event WHERE timestamp < '?'::timestamptz "
                   . "AND action = ? LIMIT ?",
            args => ['then', 'view', 5],
        );
    }

    Get_action_and_before_events_with_count_and_class: {
        Socialtext::Events->Get(action => 'view', before => 'then', count => 5,
                                class => 'page');
        sql_ok( 
            name => 'Get_action_and_before_events_with_count_and_class',
            sql => "SELECT * FROM event WHERE timestamp < '?'::timestamptz "
                   . "AND class = ? AND action = ? LIMIT ?",
            args => ['then', 'page', 'view', 5],
        );
    }
}

use constant INSERT_EVENT_SQL => qr/^INSERT INTO event /;

Creating_events: {
    Record_valid_event: {
        Socialtext::Events->Record( {
            action => 'view',
            class => 'page',
            actor => 1,
            object => 'hello_world',
            workspace => 'foobar',
        } );
        sql_ok(
            name => "Record valid event",
            sql => INSERT_EVENT_SQL,
            args => [ 'now', 'page', 'view', 1, 'hello_world', 'foobar' ],
        );
    }

    Record_event_missing_page_params: {
        my %params = (
            action => 'view', 
            class => 'page',
            actor => 1, 
            object => 'page_url_id',
            workspace => 'foobar',
        );
        for my $field (qw/action actor object workspace class/) {
            my %p = %params;
            delete $p{$field};
            eval { Socialtext::Events->Record(\%p) };
            like $@, qr/\Q$field\E parameter is missing/,
                "Record event missing page params for '$field'";
        }
    }

    Record_event_specified_timestamp: {
        Socialtext::Events->Record( {
            timestamp => 'yesterday',
            class => 'page',
            action => 'tag',
            actor => 1,
            object => 'hello_world',
            workspace => 'foobr',
        } );
        sql_ok(
            name => 'Record event specified timestamp',
            sql => INSERT_EVENT_SQL,
            args => [ 'yesterday', 'page', 'tag', 1, 'hello_world', 'foobr' ],
        );
    }

    Record_event_with_user_object: {
        Socialtext::Events->Record( {
            class => 'page',
            action => 'comment',
            actor => Socialtext::User->new( user_id => 42 ),
            object => 'hello_world',
            workspace => 'foobar',
        } );
        sql_ok(
            name => 'Record event with user object',
            sql => INSERT_EVENT_SQL,
            args => [ 'now', 'page', 'comment', 42, 'hello_world', 'foobar' ],
        );
    }
}

exit;
