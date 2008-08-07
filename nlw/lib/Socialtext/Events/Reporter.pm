package Socialtext::Events::Reporter;
# @COPYRIGHT@
use warnings;
use strict;
use Socialtext::SQL qw/sql_execute/;
use Socialtext::JSON qw/decode_json/;

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

    my %p = (
        id         => (delete $row->{$prefix.'_id'}         || undef),
        name       => (delete $row->{$prefix.'_name'}       || undef),
        first_name => (delete $row->{$prefix.'_first_name'} || ''),
        last_name  => (delete $row->{$prefix.'_last_name'}  || ''),
        email      => (delete $row->{$prefix.'_email'}      || undef),
    );

    if (!defined $p{id}) {
        $row->{$prefix} = undef;
        return;
    }

    my $full_name = _best_full_name(\%p);

    $row->{$prefix} = {
        id => $p{id},
        best_full_name => $full_name,
        uri => "/data/people/$p{id}",
    };
}

sub get_events {
    my $self = shift;
    my %opts = @_;

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

    my $where = 'WHERE ';
    if (my $w = $opts{where}) {
        $where .= $w;
        my $args=$opts{where_args};
        push @args, @$args;
    }
    elsif (@conditions) {
        $where .= join("\n  AND ", @conditions);
    }
    else {
        $where = '';
    }

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
$where
ORDER BY at DESC
$limit $offset
EOSQL
    my $sth = sql_execute($sql, @args);
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
            $page->{uri} = "/data/workspaces/$page->{workspace_name}/pages/$page->{id}";
        }

        delete $row->{person} if ($row->{event_class} ne 'person');

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
