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
    }, $class;
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

my $HAS_PEOPLE_I_CAN_SEE = <<'EOSQL';
    evt.event_class <> 'person' 
    OR (
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
EOSQL

my $I_CAN_USE_THIS_WORKSPACE = <<'EOSQL';
    w.workspace_id IS NULL OR 
    w.workspace_id IN (
        SELECT workspace_id FROM "UserWorkspaceRole" WHERE user_id = ? 
        UNION
        SELECT workspace_id
        FROM "WorkspaceRolePermission" wrp
        JOIN "Role" r USING (role_id)
        JOIN "Permission" p USING (permission_id)
        WHERE r.name = 'guest' AND p.name = 'read'
    )
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
EOSQL

sub get_events_activities {
    my ($self, $maybe_user) = @_; 
    # First we need to get the user id in case this was email or username used
    my $user = Socialtext::User->Resolve($maybe_user);
    my $user_id = $user->user_id;

    my @args;
    push @{$self->{_conditions}}, $ACTIVITIES_FOR_A_USER;
    push @{$self->{_condition_args}}, ($user_id) x 2;
    push @args, limit => 20;
    return $self->get_events(@args)
}

sub get_events {
    my $self   = shift;
    my %opts   = @_;

    my @args;
    my @conditions;

    if (my $b = $opts{before}) {
        push @conditions, 'at < ?::timestamptz';
        push @args, $b;
    }
    if (my $a = $opts{after}) {
        push @conditions, 'at > ?::timestamptz';
        push @args, $a;
    }
    if ($opts{followed}) {
        if ($opts{event_class} eq 'person') {
            push @conditions, $FOLLOWED_PEOPLE_ONLY;
            push @args, ($self->viewer->user_id) x 2;
        }
    }

    foreach my $eq_key (@QueryOrder) {
        next unless exists $opts{$eq_key};
        my $a = $opts{$eq_key};
        if ((defined $a) && (ref($a) eq "ARRAY")) {
            my $placeholders = "(".join(",", map( "?", @$a)).")";
            push @conditions, "e.$eq_key IN $placeholders";
            push @args, @$a;
        }
        elsif (defined $a) {
            push @conditions, "e.$eq_key = ?";
            push @args, $a;
        }
        else {
            push @conditions, "e.$eq_key IS NULL";
        }
    }
    
    push @conditions, @{$self->{_conditions}};
    push @args, @{$self->{_condition_args}};

    my $where = join("\n  AND ", map {"($_)"} @conditions);
    $where = " AND $where" if $where;

    my @limit_and_offset;
    my $limit = '';
    if (my $l = $opts{limit} || $opts{count}) {
        $limit = 'LIMIT ?';
        push @limit_and_offset, $l;
    }
    my $offset = '';
    if (my $o = $opts{offset}) {
        $offset = 'OFFSET ?';
        push @limit_and_offset, $o;
    }

    my $sql = <<EOSQL;
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
    WHERE ($I_CAN_USE_THIS_WORKSPACE)
      $where
    ORDER BY at DESC
) evt
WHERE
$HAS_PEOPLE_I_CAN_SEE
$limit $offset
EOSQL

    my @user_id = ($self->viewer->user_id) x 1;
    my @more_user_id = ($self->viewer->user_id) x 2;

    Socialtext::Timer->Continue('get_events');
    my $sth = sql_execute($sql, @user_id, @args, @more_user_id,
        @limit_and_offset);
    my $result = $self->decorate_event_set($sth);
    Socialtext::Timer->Pause('get_events');

    return @$result if wantarray;
    return $result;
}


1;
