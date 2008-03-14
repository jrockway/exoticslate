# @COPYRIGHT@
package Socialtext::Authz;

use strict;
use warnings;

our $VERSION = '0.01';

use Readonly;
use Socialtext::Validate qw( validate USER_TYPE PERMISSION_TYPE WORKSPACE_TYPE );


# In the future this might be a factory but for now we'll just make it
# nice and simple
sub new {
    my $class = shift;

    return bless {}, $class;
}

{
    Readonly my $spec => {
        user       => USER_TYPE,
        permission => PERMISSION_TYPE,
        workspace  => WORKSPACE_TYPE,
    };
    sub user_has_permission_for_workspace {
        my $self = shift;
        my %p = validate( @_, $spec );

        return
            $p{workspace}->permissions->user_can(
                user       => $p{user},
                permission => $p{permission},
            );
    }
}

{
    Readonly my $spec => {
        user       => USER_TYPE,
    };
    sub user_is_business_admin {
        my $self = shift;
        my %p = validate( @_, $spec );

        return $p{user}->is_business_admin;
    }
}


{
    Readonly my $spec => {
        user       => USER_TYPE,
    };
    sub user_is_technical_admin {
        my $self = shift;
        my %p = validate( @_, $spec );

        return $p{user}->is_technical_admin;
    }
}


1;

__END__

=head1 NAME

Socialtext::Authz - API for permissions checks

=head1 SYNOPSIS

  use Socialtext::Authz;

  my $authz = Socialtext::Authz->new;
  $authz->user_has_permission_for_workspace(
      user       => $user,
      permission => $permission,
      workspace  => $workspace,
  );

=head1 DESCRIPTION

This class provides an API for checking if a user has a specific
permission in a workspace. While this can be checked by using the
C<Socialtext::Workspace> class's API, the goal of this layer is to
provide an abstraction that can be used to implement authorization
outside of the DBMS, for example by using LDAP.

=head1 METHODS

This class provides the following methods:

=head2 Socialtext::Authz->new()

Returns a new C<Socialtext::Authz> object.

=head2 $authz->user_has_permission_for_workspace(PARAMS)

Returns a boolean indicating whether the user has the specified
permission for the given workspace.

Requires the following PARAMS:

=over 8

=item * user - a user object

=item * permission - a permission object

=item * workspace - a workspace object

=back

=head2 $authz->user_is_business_admin( user => $user )

=head2 $authz->user_is_technical_admin( user => $user )

Returns a boolean indicating whether the user has the named
system-wide privilege.

=head1 AUTHOR

Socialtext, C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc. All Rights Reserved.

=cut
