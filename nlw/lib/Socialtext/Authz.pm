# @COPYRIGHT@
package Socialtext::Authz;

use strict;
use warnings;

our $VERSION = '0.02';

use Readonly;
use Socialtext::Validate qw( validate USER_TYPE PERMISSION_TYPE WORKSPACE_TYPE );
use Socialtext::Timer;
use Socialtext::SQL qw/sql_singlevalue/;
use Socialtext::Cache;
use Socialtext::User::Default::Users qw(:system-user);

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

    my $user_id = $user->user_id;
    my $cache = Socialtext::Cache->cache('authz_plugin');
    my $cache_key = "user:$user_id\0$plugin_name";
    
    my $enabled = $cache->get($cache_key);
    return $enabled if defined $enabled;

    return 1 if ($user->username eq $SystemUsername);

    my $sql = <<SQL;
        SELECT 1 
        FROM account_user JOIN account_plugin USING (account_id)
        WHERE user_id = ? AND plugin = ? 
        LIMIT 1
SQL

    Socialtext::Timer->Continue('plugin_enabled_for_user');
    $enabled = sql_singlevalue($sql, $user_id, $plugin_name) ? 1 : 0;
    Socialtext::Timer->Pause('plugin_enabled_for_user');

    #warn "PLUGIN $plugin_name ENABLED FOR ".$user->username."? $enabled\n";
    $cache->set($cache_key, $enabled);
    return $enabled;
}

# is a plugin available in some common account between two users
sub plugin_enabled_for_users {
    my $self = shift;
    my %p = @_;

    my $actor = delete $p{actor};
    my $user = delete $p{user};
    my $plugin_name = delete $p{plugin_name};
    return 0 unless ($actor && $user && $plugin_name);

    my $user_id = $user->user_id;
    my $actor_id = $actor->user_id;

    if ($actor_id eq $user_id) {
        return $self->plugin_enabled_for_user(
            user => $actor,
            plugin_name => $plugin_name
        );
    }

    my $cache = Socialtext::Cache->cache('authz_plugin');
    my $cache_key = "users:$user_id\0$actor_id\0$plugin_name";
    my $enabled = $cache->get($cache_key);
    return $enabled if defined $enabled;

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

    Socialtext::Timer->Continue('plugin_enabled_for_users');
    $enabled = sql_singlevalue($sql, $plugin_name,
                               $actor_id, $user_id) ? 1 : 0;
    Socialtext::Timer->Pause('plugin_enabled_for_users');

    $cache->set($cache_key, $enabled);
    #warn "PLUGIN $plugin_name ENABLED FOR ".$actor->username." and ". $user->username ."? $enabled\n";
    return $enabled;
}

sub plugin_enabled_for_user_in_account {
    my $self = shift;
    my %p = @_;
    my $user = delete $p{user};
    my $account = delete $p{account};
    my $plugin_name = delete $p{plugin_name};

    return 1 if ($user->username eq $SystemUsername);

    my $user_id = $user->user_id;
    my $account_id = ref($account) ? $account->account_id : $account;

    my $cache = Socialtext::Cache->cache('authz_plugin');
    my $cache_key = "user_acct:$user_id\0$account_id\0$plugin_name";
    my $enabled = $cache->get($cache_key);
    return $enabled if defined $enabled;

    my $sql = <<SQL;
        SELECT 1 
        FROM account_user JOIN account_plugin USING (account_id)
        WHERE user_id = ? AND account_id = ? AND plugin = ? 
        LIMIT 1
SQL

    Socialtext::Timer->Continue('plugin_enabled_for_user_in_account');
    $enabled = sql_singlevalue($sql, $user_id, 
                               $account_id, $plugin_name) ? 1 : 0;
    Socialtext::Timer->Pause('plugin_enabled_for_user_in_account');

    $cache->set($cache_key, $enabled);
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

=head2 $authz->plugin_enabled_for_user(PARAMS)

Returns a boolean indicating whether the user has the ability to use a plugin through one of his/her account memberships.

When checking if two users can both use a plugin, see C<< $authz->plugin_enabled_for_users(PARAMS) >>.

Requires the following PARAMS:

=over 8

=item * user - a user object

=item * plugin_name - the name of the plugin to check

=back

=head2 $authz->plugin_enabled_for_users(PARAMS)

Returns a boolean indicating if a plugin can be used for some interaction between two users.  Currently, this is implemented as a check to see if both users share any accounts where the plugin is enabled.  In the future, this may be expanded out to use an access-control mechanism that may or may not use user-specified access assertions.

Requires the following PARAMS:

=over 8

=item * actor - a user object, the "subject" in an interaction.

=item * user - another user object, the "object" in an interaction.

=item * plugin_name - the name of the plugin to check

=back

Typical usage might be that actor is the current logged-in user where the actor wishes to interact with a user the context of a plugin.  To use Socialtext People as an example, actor wishes to view a user's profile: this method would return true if actor is allowed to interact with that user's profile.

=head2 $authz->plugin_enabled_for_user_in_account(PARAMS)

Returns a boolean indicating whether a user is permitted to use a plugin within the context of an account.  To use Socialtext People as an example, say the user wants to view a directory listing for an account: this method would return true if the user was able to view listings for this account.

Requires the following PARAMS:

=over 8

=item * user - a user object

=item * account - a C<Socialtext::Account> object

=item * plugin_name - the name of the plugin to check

=back

=head1 AUTHOR

Socialtext, C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc. All Rights Reserved.

=cut
