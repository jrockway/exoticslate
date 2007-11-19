# @COPYRIGHT@
package Socialtext::Permission;

use strict;
use warnings;

our $VERSION = '0.01';

use base 'Exporter';
use Class::Field 'field';
use Readonly;
use Socialtext::MultiCursor;
use Socialtext::SQL 'sql_execute';
use Socialtext::Validate qw( validate SCALAR_TYPE );

field 'permission_id';
field 'name';

sub table_name { 'Permission' }

# FIXME: This belongs elsewhere, in fixture creation code, perhaps
Readonly my @RequiredPermissions => qw(
    read edit attachments comment delete email_in email_out edit_controls
    admin_workspace request_invite impersonate
);
sub EnsureRequiredDataIsPresent {
    my $class = shift;

    for my $name (@RequiredPermissions) {
        next if $class->new( name => $name );

        $class->create( name => $name );
    }
}

_setup_exports();

sub _setup_exports {
    our @EXPORT_OK = ();

    Readonly my @ExportedPermissions => qw(
        read edit attachments comment delete email_in email_out edit_controls
        request_invite admin_workspace
    );

    foreach my $name (@ExportedPermissions) {
        my $symbol = uc "ST_${name}_PERM";

        eval "sub $symbol() { Socialtext::Permission->new( name => '$name' ) }";
        die $@ if $@;
        push @EXPORT_OK, $symbol;
    }
}

sub new {
    my ( $class, %p ) = @_;

    return exists $p{name} ? $class->_new_from_name(%p)
                           : $class->_new_from_permission_id(%p);
}

sub _new_from_name {
    my ( $class, %p ) = @_;

    return $class->_new_from_where('name=?', $p{name});
}

sub _new_from_permission_id {
    my ( $class, %p ) = @_;

    return $class->_new_from_where('permission_id=?', $p{permission_id});
}

sub _new_from_where {
    my ( $class, $where_clause, @bindings ) = @_;

    my $sth = sql_execute(
        'SELECT permission_id, name'
        . ' FROM "Permission"'
        . " WHERE $where_clause",
        @bindings );
    my @rows = @{ $sth->fetchall_arrayref };
    return @rows    ?   bless {
                            permission_id => $rows[0][0],
                            name          => $rows[0][1],
                        }, $class
                    :   undef;
}

sub create {
    my ( $class, %p ) = @_;

    sql_execute(
        'INSERT INTO "Permission" (permission_id, name)'
        . ' VALUES (nextval(\'"Permission___permission_id"\'),?)',
        $p{name} );
}

sub delete {
    my ($self) = @_;

    sql_execute( 'DELETE FROM "Permission" WHERE permission_id=?',
        $self->permission_id );
}

# "update" methods: set_permission_name
sub update {
    my ( $self, %p ) = @_;

    sql_execute( 'UPDATE "Permission" SET name=? WHERE permission_id=?',
        $p{name}, $self->permission_id );

    $self->name($p{name});

    return $self;
}

sub All {
    my ( $class, %p ) = @_;

    my $sth = sql_execute(
        'SELECT permission_id'
        . ' FROM "Permission"'
        . ' ORDER BY name' );

    return Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref ],
        apply => sub {
            my $row = shift;
            return Socialtext::Permission->new( permission_id => $row->[0] );
        }
    );
}

1;

__END__

=head1 NAME

Socialtext::Permission - A Socialtext permission object

=head1 SYNOPSIS

  use Socialtext::Permission;

  my $permission = Socialtext::Permission->new( permission_id => $permission_id );

  my $permission = Socialtext::Permission->new( permissionname => $name );

=head1 DESCRIPTION

This class provides methods for dealing with data from the Permission
table. Each object represents a single row from the table.

=head1 IMPORTABLE SUBROUTINES

Socialtext::Permission exports some convenient subroutines which make it easy
to access the permissions you need.

=head2 ST_READ_PERM

=head2 ST_EDIT_PERM

=head2 ST_ATTACHMENTS_PERM

=head2 ST_COMMENT_PERM

=head2 ST_DELETE_PERM

=head2 ST_EMAIL_IN_PERM

=head2 ST_EMAIL_OUT_PERM

=head2 ST_EDIT_CONTROLS_PERM

=head2 ST_REQUEST_INVITE_PERM

=head2 ST_ADMIN_WORKSPACE_PERM

=head1 CLASS METHODS

=over 4

=item Socialtext::Permission->new(PARAMS)

Looks for an existing permission matching PARAMS and returns a
C<Socialtext::Permission> object representing that permission if it
exists.

PARAMS can be I<one> of:

=over 8

=item * permission_id => $permission_id

=item * name => $name

=back

The set of valid names is:

=over 8

=item * read

Read pages, blogs, download attachments, etc.

=item * edit

Edit pages (including categories). Users with this permission always
see the editing controls, and so do not also need the edit_controls
permission.

=item * attachments

Upload or delete attachments (per page and globally) - global may be
moved to admin_workspace.

=item * comment

Add a comment via the web UI.

=item * delete

Delete a page or attachment.

=item * email_in

Add or update page via email.

=item * email_out

Send email via the application.

=item * edit_controls

Show edit page and new page links/buttons/etc, this simply shows the
controls, but does not actually allow the user to edit. Many controls
are still hidden, and only shown to users with "edit" permissions.

=item * request_invite

Allow this user to send requests to the admin to invite other users into
the workspace.

=item * impersonate 

Impersonate another user in the workspace

=item * admin_workspace

Edit workspace settings, invite users.

=back

=item Socialtext::Permission->create(PARAMS)

Attempts to create a permission with the given information and returns
a new C<Socialtext::Permission> object representing the new
permission.

PARAMS can include:

=over 8

=item * name - required

=back

=item Socialtext::Permission->table_name()

Return the name of the table where Permission data lives.

=item Socialtext::Permission->All()

Returns a cursor for all the permissions in the system, ordered by
name.  See L<Socialtext::AlzaboWrapper> for more details on this
method.

=item Socialtext::Permission->Count()

Returns a count of all permissions.

=item Socialtext::Permission->EnsureRequiredDataIsPresent()

Inserts required permissions into the DBMS if they are not present. See
L<Socialtext::Data> for more details on required data.

=back

=head1 OBJECT METHODS

=over 4

=item $permission->update(PARAMS)

Updates the object's information with the new key/val pairs passed in.
This method accepts the same PARAMS as C<new()>.

=item $permission->delete()

Deletes the permission from the DBMS.

=item $permission->permission_id()

=item $permission->name()

Returns the given attribute for the permission.

=back

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2006 Socialtext, Inc., All Rights Reserved.

=cut
