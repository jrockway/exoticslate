# @COPYRIGHT@
package Socialtext::Permission;


=head1 NAME

Socialtext::Permission - A Socialtext permission object

=head1 SYNOPSIS

  use Socialtext::Permission;

  my $permission = Socialtext::Permission->new( permission_id => $permission_id );

  my $permission = Socialtext::Permission->new( permissionname => $name );

=head1 DESCRIPTION

This class provides methods for dealing with data from the Permission
table. Each object represents a single row from the table.

=cut

use strict;
use warnings;

our $VERSION = '0.01';

use base qw(Exporter Socialtext::AlzaboWrapper);
use Socialtext::Validate qw( validate SCALAR_TYPE );
use Socialtext::Schema;
__PACKAGE__->SetAlzaboTable( Socialtext::Schema->Load->table('Permission') );
__PACKAGE__->MakeColumnMethods();

use Readonly;

Readonly my @RequiredPermissions => qw(
    read edit attachments comment delete email_in email_out edit_controls
    admin_workspace request_invite impersonate
);

_setup_exports();

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

=cut

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

=item Socialtext::Permission->All()

Returns a cursor for all the permissions in the system, ordered by
name.  See L<Socialtext::AlzaboWrapper> for more details on this
method.

=cut

sub All {
    my $class = shift;

    return
        $class->cursor
            ( $class->table->all_rows
                  ( order_by => $class->table->column('name') )
            );
}


=item Socialtext::Permission->Count()

Returns a count of all permissions.

=item Socialtext::Permission->EnsureRequiredDataIsPresent()

Inserts required permissions into the DBMS if they are not present. See
L<Socialtext::Data> for more details on required data.

=cut

sub EnsureRequiredDataIsPresent {
    my $class = shift;

    for my $name (@RequiredPermissions) {
        next if $class->new( name => $name );

        $class->create( name => $name );
    }
}

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

=cut

sub _new_row {
    my $class = shift;
    my %p     = validate( @_, { name => SCALAR_TYPE } );

    return $class->table->one_row(
        where => [ $class->table->column('name'), '=', $p{name } ],
    );
}

1;

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2006 Socialtext, Inc., All Rights Reserved.

=cut
