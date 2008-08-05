#!perl
# @COPYRIGHT@
use warnings;
use strict;
use Test::More tests => 67;
use Test::Exception;
use XXX;
use mocked 'Socialtext::Headers';
use mocked 'Socialtext::CGI';
use mocked 'Socialtext::SQL', 'sql_ok';
use mocked 'Socialtext::User';
use mocked 'Socialtext::Workspace';
use mocked 'Socialtext::Page';
use mocked 'Socialtext::Hub';

BEGIN {
    use_ok('Socialtext::Events');
}

my $insert_re = qr/^INSERT INTO event \( at, event_class, action, actor_id, person_id, page_id, page_workspace_id, tag_name, context \) VALUES/;

my $user = Socialtext::User->new(
    user_id => 2345, 
    name => 'tiffany'
);
my $ws = Socialtext::Workspace->new(
    id => 348798,
    name => 'forbao',
    title => 'O HAI',
);
my $hub = Socialtext::Hub->new(
    current_workspace => $ws,
    current_user => $user,
);
my $page = Socialtext::Page->new(
    id => 'example_page',
    name => 'Example Page!',
    revision_id => "abcd",
    revision_count => 56,
    hub => $hub,
);
is $page->id, 'example_page';
Socialtext::Pages->StoreMocked($page);

test_get_events: {
# test storing a string for context instead of a hash

    my $base_select = <<EOSQL;
SELECT
    e.at AT TIME ZONE 'UTC' || 'Z' AS at,
    e.event_class AS event_class,
    e.action AS action,
    actor.id AS actor_id, 
        actor.name AS actor_name,
        actor.first_name AS actor_first_name, 
        actor.last_name AS actor_last_name, 
        actor.email AS actor_email,
    person.id AS person_id, 
        person.name AS person_name,
        person.first_name AS person_first_name, 
        person.last_name AS person_last_name, 
        person.email AS person_email,
    page.page_id as page_id, 
        page.name AS page_name, 
        page.page_type AS page_type,
    w.name AS page_workspace_name, 
        w.title AS page_workspace_title,
    e.tag_name AS tag_name,
    e.context AS context
FROM event e 
    LEFT JOIN "person" actor ON e.actor_id = actor.id
    LEFT JOIN "person" person ON e.person_id = person.id
    LEFT JOIN page ON (e.page_workspace_id = page.workspace_id AND e.page_id = page.page_id)
    LEFT JOIN "Workspace" w ON (e.page_workspace_id = w.workspace_id)
EOSQL

    Get_no_events: {
        my $events = Socialtext::Events->Get();
        isa_ok $events, 'ARRAY';
        is @$events, 0, 'no events found';
        sql_ok( 
            sql => "$base_select ORDER BY at DESC",
            args => [],
        );
    }

    test_mocking: {
        my %event = ( 
            at => '2008-06-25 11:39:21.509539Z', 
            event_class => 'page',
            action => 'view',
            actor_id => 1234,
                actor_name => 'steve@foo',
                actor_email => 'steve@example.org',
                actor_first_name => 'Steve',
                actor_last_name => 'Foo',
            person_id => undef,
                person_name => undef, 
                person_email => undef,
                person_first_name => undef,
                person_last_name => undef,
            page_id => 'hello_world',
                page_name => 'Hello World',
                page_workspace_name => 'foobar',
                page_workspace_title => 'Foobar Wiki',
                page_type => 'wiki',
            tag_name => undef,
            context => '{"a":"b"}',
        );
        @Socialtext::SQL::RETURN_VALUES = ( { return => [{%event}] } );

        my $events = Socialtext::Events->Get();

        is_deeply $events, [
            {
                at => $event{at},
                event_class => 'page',
                action => 'view',
                actor => {
                    id => 1234,
                    best_full_name => "Steve Foo",
                    uri => '/data/people/1234',
                },
                page => {
                    id => $event{page_id},
                    name => $event{page_name},
                    workspace_name => $event{page_workspace_name},
                    workspace_title => $event{page_workspace_title},
                    type => 'wiki',
                    uri => '/data/workspaces/foobar/pages/hello_world',
                },
                tag_name => undef,
                context => { a => "b" },
            }
        ], 'found event';

        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            sql => "$base_select ORDER BY at DESC",
            args => [],
        );
    }

    Get_limited_events: {
        my $events = Socialtext::Events->Get(limit => 32);
        is_deeply $events, [], "no spurious events";
        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            sql => "$base_select ORDER BY at DESC LIMIT ?",
            args => [32],
        );
    }

    Get_offset_events: {
        Socialtext::Events->Get(offset => 5);
        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            sql => "$base_select ORDER BY at DESC OFFSET ?",
            args => [5],
        );
    }

    Get_limit_and_offset_events: {
        Socialtext::Events->Get(limit => 5, offset => 10);
        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            sql => "$base_select ORDER BY at DESC LIMIT ? OFFSET ?",
            args => [5, 10],
        );
    }

    Get_before_events: {
        Socialtext::Events->Get(before => 'now');
        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            sql => "$base_select WHERE at < ?::timestamptz ORDER BY at DESC",
            args => ['now'],
        );
    }

    Get_after_events: {
        Socialtext::Events->Get(after => 'now');
        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            sql => "$base_select WHERE at > ?::timestamptz ORDER BY at DESC",
            args => ['now'],
        );
    }

    Get_before_and_after: {
        # If both before and after, before wins
        Socialtext::Events->Get(before => 'then', after => 'now');
        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            sql => "$base_select WHERE at < ?::timestamptz 
                    AND at > ?::timestamptz ORDER BY at DESC",
            args => ['then', 'now'],
        );
    }

    Get_action_events: {
        Socialtext::Events->Get( action => 'View' );
        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            sql => "$base_select WHERE e.action = ? ORDER BY at DESC",
            args => ['View'],
        );
    }

    Get_action_events_for_class: {
        Socialtext::Events->Get( action => 'View', event_class => 'thingers' );
        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            sql => "$base_select WHERE e.event_class = ? AND e.action = ?
                    ORDER BY at DESC",
            args => ['thingers', 'View'],
        );
    }

    Get_action_and_before_events: {
        Socialtext::Events->Get( action => 'View', before => 'then' );
        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            sql => "$base_select WHERE at < ?::timestamptz
                   AND e.action = ? ORDER BY at DESC",
            args => ['then', 'View'],
        );
    }

    Get_action_and_before_events_with_count: {
        # count and limit are synonyms
        Socialtext::Events->Get(action => 'view', before => 'then', count => 5);
        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            name => 'Get_action_and_before_events_with_count',
            sql => "$base_select WHERE at < ?::timestamptz
                   AND e.action = ? ORDER BY at DESC LIMIT ?",
            args => ['then', 'view', 5],
        );
    }

    Get_action_and_before_events_with_count_and_class: {
        Socialtext::Events->Get(action => 'view', before => 'then', count => 5,
                                event_class => 'page');
        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            name => 'Get_action_and_before_events_with_count_and_class',
            sql => "$base_select WHERE at < ?::timestamptz
                   AND e.event_class = ? AND e.action = ? 
                   ORDER BY at DESC LIMIT ?",
            args => ['then', 'page', 'view', 5],
        );
    }
}

Creating_events: {

    Record_checks_required_params: {
        my %ev = (
            at          => 'whenevs',
            event_class => 'page',
            action      => 'view',
            actor       => 1,
            page        => 'hello_world',
            workspace   => 22,
        );

        foreach my $key (qw(event_class action actor page workspace)) {
            dies_ok {
                local $ev{$key} = undef;
                Socialtext::Events->Record(\%ev);
            } 'no event_class parameter';
            ok @Socialtext::SQL::SQL == 0, "no events recorded";
        }

        $ev{event_class} = 'person';
        delete $ev{page};
        delete $ev{workspace};

        dies_ok {
            Socialtext::Events->Record(\%ev);
        } 'no person parameter';
        ok @Socialtext::SQL::SQL == 0, "no events recorded";


        $ev{person} = 2;
        $ev{context} = "invalid json";

        dies_ok {
            Socialtext::Events->Record(\%ev);
        } 'invalid json';
        ok @Socialtext::SQL::SQL == 0, "no events recorded";
    }


    Record_valid_event: {
        Socialtext::Events->Record({
            timestamp   => 'whenevs',
            action      => 'view',
            actor       => 1,
            page        => 'hello_world',
            workspace   => 22,
            event_class => 'page',
        });
        ok @Socialtext::SQL::SQL == 1;
        sql_ok(
            name => "Record valid event",
            sql => $insert_re,
            args => [ 'whenevs', 'page', 'view', 1, undef,
                      'hello_world', 22, undef, undef ],
        );
    }

    Record_page_object: {
        Socialtext::Events->Record( {
            action => 'view',
            class => 'page',
            page => $page
        } );
        sql_ok(
            name => "Record event with page object",
            sql => $insert_re,
            args => ['now', 'page', 'view', 2345, 
                     undef, 'example_page',  348798, undef,
                     '{"revision_id":"abcd","revision_count":56}'],
        );
    }

    Record_event_specified_timestamp: {
        Socialtext::Events->Record( {
            at => 'yesterday',
            event_class => 'page',
            action => 'tag',
            actor => 4376,
            page => 'woot_woot',
            workspace => 832,
            context => '{"a":"b"}',
        } );
        sql_ok(
            name => 'Record event specified timestamp',
            sql => $insert_re,
            args => ['yesterday', 'page', 'tag', 4376, undef,
                     'woot_woot',  832, undef, '{"a":"b"}'],
        );
    }

    Record_event_with_user_object: {
        Socialtext::Events->Record( {
            actor => Socialtext::User->new( user_id => 42 ),
            person => Socialtext::User->new( user_id => 123 ),
            at => 'yesterday',
            event_class => 'page',
            action => 'tag',
            page => 'yee_haw',
            workspace => 832111,
            context => '[{"c":"d"}]',
        } );
        sql_ok(
            name => 'Record event with user object',
            sql => $insert_re,
            args => ['yesterday', 'page', 'tag', 42, 123,
                     'yee_haw', 832111, undef, '[{"c":"d"}]'],
        );
    }
}


exit;
