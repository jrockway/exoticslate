package Socialtext::Events::Reporter;
# @COPYRIGHT@
use warnings;
use strict;
use Socialtext::SQL qw/sql_execute/;
use Socialtext::JSON qw/decode_json/;
use Socialtext::User;
use Socialtext::Pluggable::Adapter;

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    return bless {}, $class;
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
    if ($user) {
        $real_name = $user->guess_real_name();
    }

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
    };
}

sub get_events_activities {
    my ($self, $viewer, $maybe_user) = @_; 
    # First we need to get the user id in case this was email or username used
    my $user = Socialtext::User->Resolve($maybe_user);
    my $user_id = $user->user_id;

    my @args;
    my $where = <<ENDWHERE;
(event_class = 'person' AND 
 action IN ('tag_add', 'edit_save') AND 
 person_id = ?) 
OR
(event_class = 'page' AND 
 action IN ('edit_save','tag_add','comment','rename','duplicate','delete') AND
 actor_id = ?)
ENDWHERE
    my $whereargs = [$user_id, $user_id];
    push @args, where => $where;
    push @args, where_args => $whereargs;
    push @args, limit => 20;
    return $self->get_events($viewer, @args)
}


sub get_events {
    my $self   = shift;
    my $viewer = shift;
    my %opts   = @_;

    unless ($viewer->can('user_id')) {
        die "Expected a viewer user as the first arg";
    }

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
            my $where = <<SQL;
(  (actor_id  IN (SELECT person_id2 FROM person_watched_people__person WHERE person_id1=?))
   OR
   (person_id IN (SELECT person_id2 FROM person_watched_people__person WHERE person_id1=?))
)
SQL
            push @conditions, $where;
            push @args, ($viewer->user_id) x 2;
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

    my $where = '';
    if (my $w = $opts{where}) {
        $where .= "($w)";
        my $args = $opts{where_args};
        push @args, @$args;
    }
    if (@conditions) {
        $where .= "\n  AND " if $where;
        $where .= join("\n  AND ", map {"($_)"} @conditions);
    }
    $where = " AND $where" if $where;

    my $limit = '';
    if (my $l = $opts{limit} || $opts{count}) {
        $limit = 'LIMIT ?';
        push @args, $l;
    }
    my $offset = '';
    if (my $o = $opts{offset}) {
        $offset = 'OFFSET ?';
        push @args, $o;
    }

    my $sql = <<EOSQL;
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
WHERE (w.workspace_id IS NULL OR w.workspace_id IN (
        SELECT workspace_id FROM "UserWorkspaceRole" WHERE user_id = ? 
        UNION
        SELECT workspace_id
        FROM "WorkspaceRolePermission" wrp
        JOIN "Role" r USING (role_id)
        JOIN "Permission" p USING (permission_id)
        WHERE r.name = 'guest' AND p.name = 'read'
    ))
    AND (e.event_class <> 'person' OR e.person_id IN (
        SELECT prsn.user_id
          FROM account_user viewer1
            JOIN account_plugin USING (account_id)
            JOIN account_user prsn USING (account_id)
          WHERE plugin = 'people' AND viewer1.user_id = ?
    ))
    AND (e.event_class <> 'person' OR e.actor_id IN (
        SELECT actr.user_id
          FROM account_user viewer2
            JOIN account_plugin USING (account_id)
            JOIN account_user actr USING (account_id)
          WHERE plugin = 'people' AND viewer2.user_id = ?
    ))
  $where
ORDER BY at DESC
$limit $offset
EOSQL
    my @user_id = ($viewer->user_id) x 3;
    my $sth = sql_execute($sql, @user_id, @args);
    my $result = [];
    while (my $row = $sth->fetchrow_hashref) {
        $self->_extract_person($row, 'actor');
        $self->_extract_person($row, 'person');

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

        delete $row->{person} 
            if (!defined($row->{person}) and $row->{event_class} ne 'person');

        $row->{page} = $page if ($row->{event_class} eq 'page');

        eval {
            $row->{context} = $row->{context} ? decode_json($row->{context})
                                              : {};
        };
        warn $@ if $@;

        push @$result, $row;
    }

    return @$result if wantarray;
    return $result;
}

1;
