package Socialtext::Events::Reporter;
# @COPYRIGHT@
use warnings;
use strict;
use Socialtext::SQL qw/sql_execute/;
use Socialtext::JSON qw/decode_json/;
use Socialtext::User;
use Socialtext::Pluggable::Adapter;
use Socialtext::Timer;
use Class::Field qw/field/;

field 'viewer';

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    return bless {
        @_,
        _conditions => [],
        _condition_args => [],
        _outer_conditions => [],
        _outer_condition_args => [],
    }, $class;
}

sub add_condition {
    my $self = shift;
    my $cond = shift;
    push @{$self->{_conditions}}, $cond;
    push @{$self->{_condition_args}}, @_;
}

sub prepend_condition {
    my $self = shift;
    my $cond = shift;
    unshift @{$self->{_conditions}}, $cond;
    unshift @{$self->{_condition_args}}, @_;
}

sub add_outer_condition {
    my $self = shift;
    my $cond = shift;
    push @{$self->{_outer_conditions}}, $cond;
    push @{$self->{_outer_condition_args}}, @_;
}

sub prepend_outer_condition {
    my $self = shift;
    my $cond = shift;
    unshift @{$self->{_outer_conditions}}, $cond;
    unshift @{$self->{_outer_condition_args}}, @_;
}

our @QueryOrder = qw(
    event_class 
    action 
    actor_id 
    person_id 
    page_workspace_id 
    page_id 
    tag_name
);

sub _best_full_name {
    my $p = shift;

    my $full_name;
    if ($p->{first_name} || $p->{last_name}) {
        $full_name = "$p->{first_name} $p->{last_name}";
    }
    elsif ($p->{email}) {
        ($full_name = $p->{email}) =~ s/@.*$//;
    }
    elsif ($p->{name}) {
        ($full_name = $p->{name}) =~ s/@.*$//;
    }
    return $full_name;
}

sub _extract_person {
    my ($self, $row, $prefix) = @_;
    my $id = delete $row->{"${prefix}_id"};
    return unless $id;

    # this real-name calculation may benefit from caching at some point
    my $real_name;
    my $user = Socialtext::User->new(user_id => $id);
    my $avatar_is_visible = $user->avatar_is_visible || 0;
    if ($user) {
        $real_name = $user->guess_real_name();
    }

    my $profile_is_visible = $user->profile_is_visible_to($self->viewer) || 0;
    my $hidden = 1;
    my $adapter = Socialtext::Pluggable::Adapter->new;
    if ($adapter->plugin_exists('people')) {
        require Socialtext::People::Profile;
        my $profile = Socialtext::People::Profile->GetProfile($user);
        $hidden = $profile->is_hidden if $profile;
    }

    $row->{$prefix} = {
        id => $id,
        best_full_name => $real_name,
        uri => "/data/people/$id",
        hidden => $hidden,
        avatar_is_visible => $avatar_is_visible,
        profile_is_visible => $profile_is_visible,
    };
}

sub _extract_page {
    my $self = shift;
    my $row = shift;

    my $page = {
        id => delete $row->{page_id} || undef,
        name => delete $row->{page_name} || undef,
        type => delete $row->{page_type} || undef,
        workspace_name => delete $row->{page_workspace_name} || undef,
        workspace_title => delete $row->{page_workspace_title} || undef,
    };

    if ($page->{workspace_name} && $page->{id}) {
        $page->{uri} = 
            "/data/workspaces/$page->{workspace_name}/pages/$page->{id}";
    }

    $row->{page} = $page if ($row->{event_class} eq 'page');
}

sub _expand_context {
    my $self = shift;
    my $row = shift;
    my $c = $row->{context};
    if ($c) {
        $c = eval { decode_json($c) };
        warn $@ if $@;
    }
    $c = defined($c) ? $c : {};
    $row->{context} = $c;
}

sub decorate_event_set {
    my $self = shift;
    my $sth = shift;

    my $result = [];

    while (my $row = $sth->fetchrow_hashref) {
        $self->_extract_person($row, 'actor');
        $self->_extract_person($row, 'person');
        $self->_extract_page($row);
        $self->_expand_context($row);

        delete $row->{person} 
            if (!defined($row->{person}) and $row->{event_class} ne 'person');

        push @$result, $row;
    }

    return $result;
}

my $FIELDS = <<'EOSQL';
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
EOSQL

sub visible_exists {
    my ($plugin, $event_field) = @_;
    return <<EOSQL;
        EXISTS (
            SELECT 1
            FROM account_user viewer
            JOIN account_plugin USING (account_id)
            JOIN account_user othr USING (account_id)
            WHERE plugin = '$plugin' AND viewer.user_id = ?
              AND othr.user_id = $event_field
        )
EOSQL
}

my $VISIBILITY_SQL = join "\n",
    '(',
        "(evt.event_class <> 'person' OR (",
            visible_exists('people', 'evt.actor_id'),
            "AND",
            visible_exists('people', 'evt.person_id'),
        '))',
        "AND ( evt.event_class <> 'signal' OR",
            visible_exists('signals', 'evt.actor_id'),
        ')',
    ')';

my $VISIBLE_WORKSPACES = <<'EOSQL';
    SELECT workspace_id FROM "UserWorkspaceRole" WHERE user_id = ? 
    UNION
    SELECT workspace_id
    FROM "WorkspaceRolePermission" wrp
    JOIN "Role" r USING (role_id)
    JOIN "Permission" p USING (permission_id)
    WHERE r.name = 'guest' AND p.name = 'read'
EOSQL

my $I_CAN_USE_THIS_WORKSPACE = <<"EOSQL";
    w.workspace_id IS NULL OR 
    w.workspace_id IN ( $VISIBLE_WORKSPACES )
EOSQL

my $FOLLOWED_PEOPLE_ONLY = <<'EOSQL';
(  
   (actor_id IN (
        SELECT person_id2 
        FROM person_watched_people__person 
        WHERE person_id1=?))
   OR
   (person_id IN (
        SELECT person_id2 
        FROM person_watched_people__person 
        WHERE person_id1=?))
)
EOSQL

my $ACTIVITIES_FOR_A_USER = <<'EOSQL';
    (event_class = 'person' AND 
     action IN ('tag_add', 'edit_save') AND 
     person_id = ?) 
    OR
    (event_class = 'page' AND 
     action IN ('edit_save','tag_add','comment',
                'rename','duplicate','delete') AND
     actor_id = ?)
    OR
    (event_class = 'signal' AND actor_id = ?)
EOSQL

my $CONTRIBUTIONS = <<'EOSQL';
    (event_class = 'person') 
    OR
    (event_class = 'page' AND 
     action IN ('edit_save','tag_add','comment',
                'rename','duplicate','delete'))
EOSQL

sub _process_before_after {
    my $self = shift;
    my $opts = shift;
    if (my $b = $opts->{before}) {
        $self->add_condition('at < ?::timestamptz', $b);
    }
    if (my $a = $opts->{after}) {
        $self->add_condition('at > ?::timestamptz', $a);
    }
}

sub _process_field_conditions {
    my $self = shift;
    my $opts = shift;

    foreach my $eq_key (@QueryOrder) {
        next unless exists $opts->{$eq_key};

        my $arg = $opts->{$eq_key};
        if ((defined $arg) && (ref($arg) eq "ARRAY")) {
            my $placeholders = "(".join(",", map( "?", @$arg)).")";
            $self->add_condition("e.$eq_key IN $placeholders", @$arg);
        }
        elsif (defined $arg) {
            $self->add_condition("e.$eq_key = ?", $arg);
        }
        else {
            $self->add_condition("e.$eq_key IS NULL");
        }
    }
}

sub _limit_and_offset {
    my $self = shift;
    my $opts = shift;

    my @args;

    my $limit = '';
    if (my $l = $opts->{limit} || $opts->{count}) {
        $limit = 'LIMIT ?';
        push @args, $l;
    }
    my $offset = '';
    if (my $o = $opts->{offset}) {
        $offset = 'OFFSET ?';
        push @args, $o;
    }

    my $statement = join(' ',$limit,$offset);
    return ($statement, @args);
}

sub _build_standard_sql {
    my $self = shift;
    my $opts = shift;

    $self->_process_before_after($opts);

    $self->prepend_condition(
        $I_CAN_USE_THIS_WORKSPACE => $self->viewer->user_id
    );
    $self->add_outer_condition(
        $VISIBILITY_SQL => ($self->viewer->user_id) x 3
    );

    if ($opts->{followed}) {
        $self->add_condition(
            $FOLLOWED_PEOPLE_ONLY => ($self->viewer->user_id) x 2
        );
        # limiting to these event types will give a bit of a perf boost:
        $opts->{event_class} = ['person','page'];
    }

    # filter for contributions-type events
    $self->add_condition($CONTRIBUTIONS)
        if $opts->{contributions};

    $self->_process_field_conditions($opts);

    my ($limit_stmt, @limit_args) = $self->_limit_and_offset($opts);

    my $where = join("\n  AND ", 
                     map {"($_)"} @{$self->{_conditions}});
    my $outer_where = join("\n  AND ", 
                           map {"($_)"} @{$self->{_outer_conditions}});

    my $sql = <<EOSQL;
SELECT * FROM (
    SELECT $FIELDS
    FROM event e 
        LEFT JOIN page ON (e.page_workspace_id = page.workspace_id AND 
                           e.page_id = page.page_id)
        LEFT JOIN "Workspace" w ON (e.page_workspace_id = w.workspace_id)
    WHERE $where
    ORDER BY at DESC
) evt
WHERE
$outer_where
$limit_stmt
EOSQL

    return $sql, [@{$self->{_condition_args}}, @{$self->{_outer_condition_args}}, @limit_args];
}

sub get_events {
    my $self   = shift;
    my $opts   = {@_};

    my ($sql, $args) = $self->_build_standard_sql($opts);

    Socialtext::Timer->Continue('get_events');
    my $sth = sql_execute($sql, @$args);
    my $result = $self->decorate_event_set($sth);
    Socialtext::Timer->Pause('get_events');

    return @$result if wantarray;
    return $result;
}

sub get_events_activities {
    my ($self, $maybe_user) = @_; 
    # First we need to get the user id in case this was email or username used
    my $user = Socialtext::User->Resolve($maybe_user);
    my $user_id = $user->user_id;

    $self->add_condition($ACTIVITIES_FOR_A_USER, ($user_id) x 3);
    return $self->get_events(@_)
}

my $PAGES_I_CARE_ABOUT = <<'EOSQL';
    SELECT page_id, page_workspace_id, MIN(at) as at
    FROM (
        -- pages i've contributed to:
        SELECT my_contribs.page_id, my_contribs.page_workspace_id, 
               MIN(my_contribs.at) as at
        FROM event my_contribs
        WHERE my_contribs.event_class = 'page' 
          AND is_page_contribution(my_contribs.action)
          AND my_contribs.actor_id = ?
        GROUP BY my_contribs.page_id, my_contribs.page_workspace_id

        UNION ALL

        -- pages i created:
        SELECT page_id, workspace_id as page_workspace_id, create_time as at
        FROM page
        WHERE creator_id = ?

        UNION ALL

        -- pages i'm watching:
        SELECT page_text_id::text as page_id, 
               workspace_id as page_workspace_id,
               '-infinity'::timestamptz as at
        FROM "Watchlist"
        WHERE user_id = ?
    ) all_my_pages
    WHERE all_my_pages.page_workspace_id IN ([% workspaces %])
    GROUP BY all_my_pages.page_id, all_my_pages.page_workspace_id
    ORDER BY at DESC
EOSQL

my $CONVERSATIONS = <<"EOSQL";
    SELECT their_contribs.*
    FROM ($PAGES_I_CARE_ABOUT) my_pages
    JOIN event their_contribs USING (page_id, page_workspace_id)
    WHERE their_contribs.at > my_pages.at
      AND their_contribs.event_class = 'page'
      AND is_page_contribution(their_contribs.action)
      AND their_contribs.actor_id <> ?
    ORDER BY their_contribs.at DESC 
    [% limit_and_offset %]
EOSQL

sub _build_convos_sql {
    my $self = shift;
    my $opts = shift;

    my $workspaces_sql = <<"EOSQL";
        SELECT DISTINCT workspace_id 
        FROM ($VISIBLE_WORKSPACES) vw
EOSQL

    my $sql = <<"EOSQL";
        SELECT $FIELDS
        FROM ($CONVERSATIONS) e
        LEFT JOIN page ON (e.page_workspace_id = page.workspace_id AND 
                           e.page_id = page.page_id)
        LEFT JOIN "Workspace" w ON (e.page_workspace_id = w.workspace_id)
EOSQL
    my $user_id = $opts->{user_id};

    my ($limit_stmt, @limit_args) = $self->_limit_and_offset($opts);
    $sql =~ s/\[\% limit_and_offset \%\]/$limit_stmt/;

    Socialtext::Timer->Continue('get_convos');
    my $ws_sth = sql_execute($workspaces_sql, $user_id);
    my @ws = map {$_->[0]} @{$ws_sth->fetchall_arrayref};
    Socialtext::Timer->Pause('get_convos');
    
    return unless @ws;

    my $ws_plc = join(',', ('?') x scalar @ws);
    $sql =~ s/\[\% workspaces \%\]/$ws_plc/;

    return $sql, [($user_id) x 3, @ws, $user_id, @limit_args];
}

sub get_events_conversations {
    my $self = shift;
    my $maybe_user = shift;
    my $opts = {@_};

    # First we need to get the user id in case this was email or username used
    my $user = Socialtext::User->Resolve($maybe_user);
    my $user_id = $user->user_id;
    $opts->{user_id} = $user_id;

    my ($sql, $args) = $self->_build_convos_sql($opts);

    return [] unless $sql;

    Socialtext::Timer->Continue('get_convos');

    my $sth = sql_execute($sql, @$args);
    my $result = $self->decorate_event_set($sth);

    Socialtext::Timer->Pause('get_convos');

    return @$result if wantarray;
    return $result;
}

sub get_awesome_events {
    my $self = shift;
    my $opts = {@_};

    $opts->{followed} = 1;
    $opts->{contributions} = 1;
    my ($followed_sql, $followed_args) = $self->_build_standard_sql($opts);

    delete $opts->{followed};
    delete $opts->{contributions};
    $opts->{user_id} = $self->viewer->user_id;
    my ($convos_sql, $convos_args) = $self->_build_convos_sql($opts);
    if (!$convos_sql) {
        return $self->get_events(%$opts);
    }

    my ($limit_stmt, @limit_args) = $self->_limit_and_offset($opts);

    my $sql = <<EOSQL;
        SELECT * FROM (
            ($followed_sql)
            UNION
            ($convos_sql)
        ) awesome
        ORDER BY at DESC
        $limit_stmt
EOSQL

    Socialtext::Timer->Continue('get_awesome');

    local $Socialtext::SQL::TRACE_SQL = 1;

    my $sth = sql_execute($sql, @$followed_args, @$convos_args, @limit_args);
    $Socialtext::SQL::TRACE_SQL = 0;
    my $result = $self->decorate_event_set($sth);

    Socialtext::Timer->Pause('get_awesome');

    return $result;
}

1;
