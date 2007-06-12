# @COPYRIGHT@
package Socialtext::Role;

use strict;
use warnings;

our $VERSION = '0.01';

use Socialtext::Exceptions qw( data_validation_error );
use Socialtext::Validate qw( validate SCALAR_TYPE );

use Socialtext::Schema;
use base 'Socialtext::AlzaboWrapper';
__PACKAGE__->SetAlzaboTable( Socialtext::Schema->Load->table('Role') );
__PACKAGE__->MakeColumnMethods();

use Readonly;


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

sub _new_row {
    my $class = shift;
    my %p     = validate( @_, { name => SCALAR_TYPE } );

    return $class->table->one_row(
        where => [ $class->table->column('name'), '=', $p{name } ],
    );
}

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
    my $class = shift;

    return
        $class->cursor
            ( $class->table->all_rows
                  ( order_by => $class->table->column('name') )
            );
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
See L<Socialtext::AlzaboWrapper> for more details on this method.

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
