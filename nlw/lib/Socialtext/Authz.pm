# @COPYRIGHT@
package Socialtext::Authz;

use strict;
use warnings;

our $VERSION = '0.02';

use Readonly;
use Socialtext::Validate qw( validate USER_TYPE PERMISSION_TYPE WORKSPACE_TYPE );
use Socialtext::Timer;
use Socialtext::SQL qw/sql_singlevalue/;

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

sub plugin_enabled_for_user {
    my $self = shift;
    my %p = @_;
    my $user = delete $p{user};
    my $plugin_name = delete $p{plugin_name};

    # circular ref:
    require Socialtext::User::Default::Factory;
    return 1 if ($user->username eq 
                 $Socialtext::User::Default::Factory::SystemUsername);

    my $sql = <<SQL;
        SELECT 1 
        FROM account_user JOIN account_plugin USING (account_id)
        WHERE user_id = ? AND plugin = ? 
        LIMIT 1
SQL

    Socialtext::Timer->Start('can_use_plugin');
    my $enabled = sql_singlevalue($sql, $user->user_id, $plugin_name);
    Socialtext::Timer->Stop('can_use_plugin');
    #warn "PLUGIN $plugin_name ENABLED FOR ".$user->username."? $enabled\n";
    return ($enabled ? 1 : 0);
}

# is a plugin available in some common account between two users
sub plugin_enabled_for_users {
    my $self = shift;
    my %p = @_;

    my $user_a = delete $p{user_a};
    my $user_b = delete $p{user_b};
    my $plugin_name = delete $p{plugin_name};
    return 0 unless ($user_a && $user_b && $plugin_name);

    if ($user_a->user_id eq $user_b->user_id) {
        return $self->plugin_enabled_for_user(
            user => $user_a,
            plugin_name => $plugin_name
        );
    }

    # This reads "find all accounts with plugin X that are related to user A,
    # then check each account to see if user B is in it".
    # This should be faster on average than just joining r1 and r2 when using
    # LIMIT 1"
    my $sql = <<SQL;
        SELECT account_id
        FROM account_user r1
        JOIN account_plugin p1 USING (account_id)
        WHERE p1.plugin = ? AND r1.user_id = ?
          AND EXISTS (
                SELECT 1
                FROM account_user r2
                WHERE r1.account_id = r2.account_id 
                  AND r2.user_id = ?
          )
        LIMIT 1
SQL

    Socialtext::Timer->Start('can_use_plugin');
    my $enabled = sql_singlevalue($sql, $plugin_name, 
                                  $user_a->user_id, $user_b->user_id);
    Socialtext::Timer->Stop('can_use_plugin');
    #warn "PLUGIN $plugin_name ENABLED FOR ".$user_a->username." and ". $user_b->username ."? $enabled\n";
    return ($enabled ? 1 : 0);
}

sub plugin_enabled_for_user_in_account {
    my $self = shift;
    my %p = @_;
    my $user = delete $p{user};
    my $account = delete $p{account};
    my $plugin_name = delete $p{plugin_name};

    # circular ref:
    require Socialtext::User::Default::Factory;
    return 1 if ($user->username eq 
                 $Socialtext::User::Default::Factory::SystemUsername);

    my $sql = <<SQL;
        SELECT 1 
        FROM account_user JOIN account_plugin USING (account_id)
        WHERE user_id = ? AND account_id = ? AND plugin = ? 
        LIMIT 1
SQL

    Socialtext::Timer->Start('can_use_plugin');
    my $enabled = sql_singlevalue($sql, $user->user_id, 
                                  $account->account_id, $plugin_name);
    Socialtext::Timer->Stop('can_use_plugin');
    return ($enabled ? 1 : 0);
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
