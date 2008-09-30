#!perl
# @COPYRIGHT@
use warnings;
use strict;
use Test::More tests => 69;
use Test::Exception;
use mocked 'Socialtext::Headers';
use mocked 'Socialtext::CGI';
use mocked 'Socialtext::SQL', 'sql_ok';
use mocked 'Socialtext::Workspace';
use mocked 'Socialtext::Page';
use mocked 'Socialtext::User';
use mocked 'Socialtext::Hub';

BEGIN {
    use_ok('Socialtext::Events');
}

my $insert_re = qr/^INSERT INTO event \( at, event_class, action, actor_id, person_id, page_id, page_workspace_id, tag_name, context \) VALUES/;

my $user = Socialtext::User->new(
    user_id => 2345, 
    name => 'tiffany'
);
my $viewer = $user;
my @viewer_args = ($viewer->user_id) x 3;
my $ws = Socialtext::Workspace->new(
    workspace_id => 348798,
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

    my $base_select = <<'EOSQL';
SELECT * FROM (
    SELECT
        e.at AT TIME ZONE 'UTC' || 'Z' AS at,
        e.event_class AS event_class,
        e.action AS action,
        e.actor_id AS actor_id, 
        e.person_id AS person_id, 
        page.page_id as page_id, 
            page.name AS page_name, 
            page.page_type AS page_type,
        w.name AS page_workspace_name, 
            w.title AS page_workspace_title,
        e.tag_name AS tag_name,
        e.context AS context
    FROM event e 
        LEFT JOIN page ON (e.page_workspace_id = page.workspace_id AND 
                           e.page_id = page.page_id)
        LEFT JOIN "Workspace" w ON (e.page_workspace_id = w.workspace_id)
    WHERE (
        w.workspace_id IS NULL OR w.workspace_id IN (
            SELECT workspace_id FROM "UserWorkspaceRole" WHERE user_id = ? 
            UNION
            SELECT workspace_id
            FROM "WorkspaceRolePermission" wrp
            JOIN "Role" r USING (role_id)
            JOIN "Permission" p USING (permission_id)
            WHERE r.name = 'guest' AND p.name = 'read'
        )
    )
EOSQL

    my $tail_select = <<'EOSQL';
    ORDER BY at DESC
) evt
WHERE ( 
evt.event_class <> 'person' OR (
    -- does the user share an account with the actor for person events
    EXISTS (
        SELECT 1
        FROM account_user viewer_a
        JOIN account_plugin USING (account_id)
        JOIN account_user actr USING (account_id)
        WHERE plugin = 'people' AND viewer_a.user_id = ?
          AND actr.user_id = evt.actor_id
    )
    AND 
    -- does the user share an account with the person for person events
    EXISTS (
        SELECT 1
        FROM account_user viewer_b
        JOIN account_plugin USING (account_id)
        JOIN account_user prsn USING (account_id)
        WHERE plugin = 'people' AND viewer_b.user_id = ?
          AND prsn.user_id = evt.person_id
    )
)
)
EOSQL

    Get_no_events: {
        my $events = Socialtext::Events->Get($viewer);
        isa_ok $events, 'ARRAY';
        is @$events, 0, 'no events found';
        sql_ok( 
            sql => "$base_select $tail_select",
            args => [@viewer_args],
        );
    }

    test_mocking: {
        local $Socialtext::User::Users{1234} = Socialtext::User->new(
            user_id => 1234,
            first_name => 'Steve',
            last_name => 'Foo',
        );
        my %event = ( 
            at => '2008-06-25 11:39:21.509539Z', 
            event_class => 'page',
            action => 'view',
            actor_id => 1234,
            person_id => undef,
            page_id => 'hello_world',
                page_name => 'Hello World',
                page_workspace_name => 'foobar',
                page_workspace_title => 'Foobar Wiki',
                page_type => 'wiki',
            tag_name => undef,
            context => '{"a":"b"}',
        );
        @Socialtext::SQL::RETURN_VALUES = ( { return => [{%event}] } );

        my $events = Socialtext::Events->Get($viewer);
        is_deeply $events, [
            {
                at => $event{at},
                event_class => 'page',
                action => 'view',
                actor => {
                    id => 1234,
                    best_full_name => "Steve Foo",
                    uri => '/data/people/1234',
                    hidden => 1,
                    avatar_is_visible => 1,
                    profile_is_visible => 1
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

        is scalar(@Socialtext::SQL::SQL), 2, 'correct # of sql left';
        sql_ok( 
            sql => "$base_select $tail_select",
            args => [@viewer_args],
        );
        sql_ok( 
            sql => "SELECT * FROM person WHERE id = ?",
            args => [1234],
        );
    }

    Get_limited_events: {
        my $events = Socialtext::Events->Get($viewer, limit => 32);
        is_deeply $events, [], "no spurious events";
        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            sql => "$base_select $tail_select LIMIT ?",
            args => [@viewer_args, 32],
        );
    }

    Get_offset_events: {
        Socialtext::Events->Get($viewer, offset => 5);
        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            sql => "$base_select $tail_select OFFSET ?",
            args => [@viewer_args, 5],
        );
    }

    Get_limit_and_offset_events: {
        Socialtext::Events->Get($viewer, limit => 5, offset => 10);
        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            sql => "$base_select $tail_select LIMIT ? OFFSET ?",
            args => [@viewer_args, 5, 10],
        );
    }

    Get_before_events: {
        Socialtext::Events->Get($viewer, before => 'now');
        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            sql => "$base_select AND (at < ?::timestamptz) $tail_select",
            args => [$viewer_args[0], 'now', @viewer_args[1,2]],
        );
    }

    Get_after_events: {
        Socialtext::Events->Get($viewer, after => 'now');
        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            sql => "$base_select AND (at > ?::timestamptz) $tail_select",
            args => [$viewer_args[0], 'now', @viewer_args[1,2]],
        );
    }

    Get_before_and_after: {
        # If both before and after, before wins
        Socialtext::Events->Get($viewer, before => 'then', after => 'now');
        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            sql => "$base_select AND (at < ?::timestamptz)
                                 AND (at > ?::timestamptz) $tail_select",
            args => [$viewer_args[0], 'then', 'now', @viewer_args[1,2]],
        );
    }

    Get_action_events: {
        Socialtext::Events->Get($viewer,  action => 'View' );
        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            sql => "$base_select AND (e.action = ?) $tail_select",
            args => [$viewer_args[0], 'View', @viewer_args[1,2]],
        );
    }

    Get_action_events_for_class: {
        Socialtext::Events->Get($viewer,  action => 'View', event_class => 'thingers' );
        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            sql => "$base_select AND (e.event_class = ?) AND (e.action = ?)
                    $tail_select",
            args => [$viewer_args[0], 'thingers', 'View', @viewer_args[1,2]],
        );
    }

    Get_action_and_before_events: {
        Socialtext::Events->Get($viewer,  action => 'View', before => 'then' );
        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            sql => "$base_select AND (at < ?::timestamptz) AND (e.action = ?)
                    $tail_select",
            args => [$viewer_args[0], 'then', 'View', @viewer_args[1,2]],
        );
    }

    Get_action_and_before_events_with_count: {
        # count and limit are synonyms
        Socialtext::Events->Get($viewer, action => 'view', before => 'then', count => 5);
        ok @Socialtext::SQL::SQL == 1;
        sql_ok( 
            name => 'Get_action_and_before_events_with_count',
            sql => "$base_select AND (at < ?::timestamptz) AND (e.action = ?)
                    $tail_select LIMIT ?",
            args => [$viewer_args[0], 'then', 'view', @viewer_args[1,2], 5],
        );
    }

    Get_action_and_before_events_with_count_and_class: {
        Socialtext::Events->Get($viewer, action => 'view', before => 'then', count => 5,
                                event_class => 'page');
        ok @Socialtext::SQL::SQL == 1;
        sql_ok(
            name => 'Get_action_and_before_events_with_count_and_class',
            sql  => "$base_select AND (at < ?::timestamptz) 
                     AND (e.event_class = ?) AND (e.action = ?)
                     $tail_select LIMIT ?",
            args => [
                $viewer_args[0], 'then', 'page', 'view',
                @viewer_args[1,2], 5
            ],
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
            action      => 'view',
            event_class => 'page',
            page        => $page
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
