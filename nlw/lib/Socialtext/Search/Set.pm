# @COPYRIGHT@

package Socialtext::Search::Set;

use strict;
use warnings;
use Class::Field 'field';
use Socialtext::MultiCursor;
use Socialtext::SQL qw( sql_execute sql_singlevalue );

field 'search_set_id';
field 'name';
field 'user_id';

sub AllForUser {
    my ( $class, $user ) = @_;

    my $sth = sql_execute(
        'SELECT name FROM search_sets WHERE owner_user_id = ?',
        $user->user_id );

    return Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref ],
        apply => sub {
            $class->new(name => $_[0]->[0], user => $user);
        }
    );
}

# USAGE: Socialtext::Search::Set->new( name => 'blort', user => $user );
sub new {
    my ( $class, %p ) = @_;
    my $user_id = $p{user}->user_id;

    my $search_set_id = sql_singlevalue(
        'SELECT search_set_id FROM search_sets '
        . 'WHERE name = ? AND owner_user_id = ?',
        $p{name}, $user_id );

    return undef unless $search_set_id;

    my $new_search_set = bless {}, $class;
    $new_search_set->user_id($user_id);
    $new_search_set->search_set_id($search_set_id);
    $new_search_set->name($p{name});

    return $new_search_set;
}

# USAGE: Socialtext::Search::Set->create( name => 'blort', user => $user);
sub create {
    my ( $class, %p ) = @_;

    return unless sql_execute(
        'INSERT INTO search_sets (search_set_id, name, owner_user_id) '
        . q{VALUES (nextval('search_sets___search_set_id'),?,?)},
        $p{name}, $p{user}->user_id );

    return $class->new(%p);
}

# Is our convention 'delete' or 'remove'?
sub delete {
    my ( $self ) = @_;

    sql_execute(
        'DELETE FROM search_sets WHERE search_set_id = ?',
        $self->search_set_id );
}

# Add the named workspace to the set.
sub add_workspace_name {
    my ( $self, $ws_name ) = @_;

    sql_execute(
        'INSERT INTO search_set_workspaces (search_set_id,workspace_id) '
        . 'VALUES (?, (SELECT workspace_id FROM "Workspace" WHERE name=?))',
        $self->search_set_id, $ws_name );
}

# Remove the named workspace from the set.
sub remove_workspace_name {
    my ( $self, $ws_name ) = @_;

    sql_execute(
        'DELETE FROM search_set_workspaces '
        . 'WHERE search_set_id = ? AND '
        . 'workspace_id = (SELECT workspace_id FROM "Workspace" WHERE name=?)',
        $self->search_set_id, $ws_name );
}

# Returns a list/iterator of the workspace names in this search set.
sub workspace_names {
    my ( $self ) = @_;

    my $sth = sql_execute(
        'SELECT w.name '
        . 'FROM "Workspace" w, search_set_workspaces ssw '
        . 'WHERE search_set_id = ? AND ssw.workspace_id = w.workspace_id',
        $self->search_set_id );

    return Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref ],
        apply => sub { $_[0]->[0] }, # dereference the name in the row arrayref
    );
}

1;
