# @COPYRIGHT@
package Socialtext::Authz::SimpleChecker;

use strict;
use warnings;

our $VERSION = '0.01';

use Readonly;
use Socialtext::Authz;
use Socialtext::Permission;
use Socialtext::Validate qw( validate USER_TYPE WORKSPACE_TYPE );


{
    Readonly my $spec => {
        user       => USER_TYPE,
        workspace  => WORKSPACE_TYPE,
    };
    sub new {
        my $class = shift;
        my %p = validate( @_, $spec );

        my $authz = Socialtext::Authz->new();

        return bless { %p, authz => $authz }, $class;
    }
}

sub check_permission {
    my $self = shift;
    my $perm = shift;

    return $self->{has_perm}{$perm}
        if exists $self->{has_perm}{$perm};

    $self->{has_perm}{$perm} =
        $self->{authz}->user_has_permission_for_workspace(
            user       => $self->{user},
            permission => Socialtext::Permission->new( name => $perm ),
            workspace  => $self->{workspace},
        );

    return $self->{has_perm}{$perm};
}


1;

__END__

=head1 NAME

Socialtext::Authz::SimpleChecker - Simplified permission checks

=head1 SYNOPSIS

  use Socialtext::Authz::SimpleChecker

  my $checker = Socialtext::Authz::SimpleChecker->new(
      user       => $user,
      workspace  => $workspace,
  );

  if ( $checker->check_permission('read') ) {
      ....
  }

=head1 DESCRIPTION

This module simplifies permission checking by storing a user and
workspace internally, and accepting permission names as strings. It is
primarily intended for use inside templates, to make them read more
nicely in the common case of checking permissions for the current user
on the current workspace.

=head1 METHODS/FUNCTIONS

This class provides the following methods:

=head2 Socialtext::Authz::SimpleChecker->new(PARAMS)

Returns a new C<Socialtext::Authz::SimpleChecker> object for a given
user and workspace.

Requires the following PARMS:

=over 8

=item * user - a user object

=item * workspace - a workspace object

=back

=head2 $checker->check_permission($perm_name)

Given a permission name (not an object), returns a boolean indicating
whether the object's user has that permission for the object's workspace.

=head1 CACHING

This object will cache the results of a lookup for a particular
permission. This helps speed up a single request, because we check the
same permission many times. However, it does mean that this object
should not be long-lived. As long as a new one is created for each web
request (or CLI interaction, etc.) the caching should be safe.

=head1 AUTHOR

Socialtext, C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc. All Rights Reserved.

=cut
