# @COPYRIGHT@
package Socialtext::UserWorkspaceRole;

use strict;
use warnings;

our $VERSION = '0.01';


use Socialtext::Schema;
use base 'Socialtext::AlzaboWrapper';
__PACKAGE__->SetAlzaboTable( Socialtext::Schema->Load()->table('UserWorkspaceRole') );
__PACKAGE__->MakeColumnMethods();


1;

__END__

=head1 NAME

Socialtext::UserWorkspaceRole - A user's role in a specific workspace

=head1 SYNOPSIS

  my $uwr = Socialtext::UserWorkspaceRole->new(
      user_id      => $user_id,
      workspace_id => $workspace_id,
  );

=head1 DESCRIPTION

This class provides methods for dealing with data from the
UserWorkspaceRole table. Each object represents a single row from the
table.

=head1 METHODS

=over 4

=item Socialtext::UserWorkspaceRole->new(PARAMS)

Looks for an existing UserWorkspaceRole matching PARAMS and returns a
C<Socialtext::UserWorkspaceRole> object representing that row if it
exists.

PARAMS I<must> be:

=over 8

=item * user_id => $user_id

=item * workspace_id => $workspace_id

=back

=item Socialtext::UserWorkspaceRole->create(PARAMS)

Attempts to create a role with the given information and returns a new
C<Socialtext::UserWorkspaceRole> object representing the new role.

PARAMS can include:

=over 8

=item * user_id - required

=item * workspace_id - required

=item * role_id - required

=item * is_selected - defaults to 0

=back

=item $uwr->update(PARAMS)

Updates the object's information with the new key/val pairs passed in.
This method accepts the same PARAMS as C<new()>.

=over 4

=item $uwr->user_id()

=item $uwr->workspace_id()

=item $uwr->role_id()

=item $uwr->is_selected()

Returns the corresponding attribute for the object.

=back

=item $uwr->delete()

Deletes the object from the DBMS.

=back

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2006 Socialtext, Inc., All Rights Reserved.

=cut
