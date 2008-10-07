# @COPYRIGHT@
package Socialtext::Role;

use strict;
use warnings;

our $VERSION = '0.01';

use Class::Field 'field';
use Readonly;
use Socialtext::Exceptions qw( data_validation_error );
use Socialtext::MultiCursor;
use Socialtext::SQL 'sql_execute';
use Socialtext::Validate qw( validate SCALAR_TYPE );

field 'role_id';
field 'name';
field 'used_as_default';

# FIXME: This belongs elsewhere, in fixture creation code, perhaps
Readonly my @RequiredRoles => (
    [ guest => 1 ],
    [ authenticated_user => 1 ],
    [ member => 0 ],
    [ workspace_admin => 0 ],
    [ impersonator => 0 ],
);
sub EnsureRequiredDataIsPresent {
    my $class = shift;

    for my $role (@RequiredRoles) {
        my ( $name, $default ) = @$role;

        next if $class->new( name => $name );

        $class->create(
           name            => $name,
           used_as_default => $default,
        );
    }
}

sub new {
    my ( $class, %p ) = @_;

    return exists $p{name} ? $class->_new_from_name(%p)
                           : $class->_new_from_role_id(%p);
}

sub _new_from_name {
    my ( $class, %p ) = @_;

    return $class->_new_from_where('name=?', $p{name});
}

sub _new_from_role_id {
    my ( $class, %p ) = @_;

    return $class->_new_from_where('role_id=?', $p{role_id});
}

sub _new_from_where {
    my ( $class, $where_clause, @bindings ) = @_;

    my $sth = sql_execute(
        'SELECT role_id, name, used_as_default'
        . ' FROM "Role"'
        . " WHERE $where_clause",
        @bindings );
    my @rows = @{ $sth->fetchall_arrayref };
    return @rows    ?   bless {
                            role_id         => $rows[0][0],
                            name            => $rows[0][1],
                            used_as_default => $rows[0][2],
                        }, $class
                    :   undef;
}

sub create {
    my ( $class, %p ) = @_;

    $class->_validate_and_clean_data(\%p);

    sql_execute(
        'INSERT INTO "Role" (role_id, name, used_as_default)'
        . ' VALUES (nextval(\'"Role___role_id"\'),?,?)',
        $p{name}, $p{used_as_default} );
}

sub delete {
    my ($self) = @_;

    sql_execute( 'DELETE FROM "Role" WHERE role_id=?',
        $self->role_id );
}

# "update" methods: set_role_name
sub update {
    my ( $self, %p ) = @_;

    $self->_validate_and_clean_data(\%p);
    sql_execute( 'UPDATE "Role" SET name=? WHERE role_id=?',
        $p{name}, $self->role_id );

    $self->name($p{name});

    return $self;
}

sub display_name {
    return join ' ', split /_/, $_[0]->name;
}

sub Guest {
    shift->new( name => 'guest' );
}

sub AuthenticatedUser {
    shift->new( name => 'authenticated_user' );
}

sub Member {
    shift->new( name => 'member' );
}

sub WorkspaceAdmin {
    shift->new( name => 'workspace_admin' );
}

sub Impersonator {
    shift->new( name => 'impersonator' );
}

sub All {
    my ( $class, %p ) = @_;

    my $sth = sql_execute(
        'SELECT role_id'
        . ' FROM "Role"'
        . ' ORDER BY name' );

    return Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref ],
        apply => sub {
            my $row = shift;
            return Socialtext::Role->new( role_id => $row->[0] );
        }
    );
}

# Helper methods

sub _validate_and_clean_data {
    my $self = shift;
    my $p = shift;

    my $is_create = ref $self ? 0 : 1;

    $p->{name} = Socialtext::String::trim( $p->{name} );

    my @errors;
    if ( ( exists $p->{name} or $is_create )
         and not
         ( defined $p->{name} and length $p->{name} ) ) {
        push @errors, "Role name is a required field.";
    }

    if ( defined $p->{name} && Socialtext::Role->new( name => $p->{name} ) ) {
        push @errors, "The role name you chose, $p->{name}, is already in use.";
    }

    if ( not $is_create and $p->{can_be_default} ) {
        push @errors, "You cannot change can_be_default for a role after it has been created.";
    }

    data_validation_error errors => \@errors if @errors;
}

1;

__END__

=head1 NAME

Socialtext::Role - A Socialtext role object

=head1 SYNOPSIS

  use Socialtext::Role;

  my $role = Socialtext::Role->new( role_id => $role_id );

  my $role = Socialtext::Role->new( name => $name );

=head1 DESCRIPTION

This class provides methods for dealing with data from the Role
table. Each object represents a single row from the table.

=head1 METHODS

=over 4

=item Socialtext::Role->new(PARAMS)

Looks for an existing role matching PARAMS and returns a
C<Socialtext::Role> object representing that role if it exists.

PARAMS can be I<one> of:

=over 8

=item * role_id => $role_id

=item * name => $name

=back

=item Socialtext::Role->create(PARAMS)

Attempts to create a role with the given information and returns
a new C<Socialtext::Role> object representing the new role.

PARAMS can include:

=over 8

=item * name - required

=item * can_be_default

=back

=item $role->update(PARAMS)

Updates the role's information with the new key/val pairs passed in.
This method accepts the same PARAMS as C<new()>, but you cannot change
"can_be_default" after the initial creation of a row.

=item $role->delete()

Deletes the role from the DBMS.

=item $role->role_id()

=item $role->name()

=item $role->can_be_default()

Returns the given attribute for the role.

=item $role->display_name()

Returns the role's name, but with underscores replaced by spaces.

=item Socialtext::Role->Guest()

=item Socialtext::Role->AuthenticatedUser()

=item Socialtext::Role->Member()

=item Socialtext::Role->WorkspaceAdmin()

=item Socialtext::Role->Impersonator()

Shortcut class methods for getting a role object for the specified
role.

=item Socialtext::Role->All()

Returns a cursor for all the accounts in the system, ordered by name.
See L<Socialtext::MultiCursor> for more details on this method.

=item Socialtext::Role->Count()

Returns a count of all accounts.

=item Socialtext::Role->EnsureRequiredDataIsPresent()

Inserts required roles into the DBMS if they are not present. See
L<Socialtext::Data> for more details on required data.

=back

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2006 Socialtext, Inc., All Rights Reserved.

=cut
