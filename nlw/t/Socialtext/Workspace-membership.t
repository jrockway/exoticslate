#!perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext tests => 7;
fixtures( 'rdbms_clean' );

use IO::String;
use Log::Dispatch::Handle;
use Socialtext::Account;
use Socialtext::Role;
use Socialtext::Workspace;

my $ws = Socialtext::Workspace->create(
    name       => 'test',
    title      => 'Test',
    account_id => Socialtext::Account->Socialtext()->account_id,
);

my $user = Socialtext::User->create(
    username      => 'dbowie@example.com',
    email_address => 'dbowie@example.com',,
);

ADD_USER:
{
    my $log_output = '';
    Socialtext::Log->new()->log()->add(
        Log::Dispatch::Handle->new(
            name      => 'string-handle',
            min_level => 'info',
            handle    => IO::String->new($log_output),
        )
    );

    $ws->add_user( user => $user );

    ok( $ws->has_user( $user ), 'user is now a member of the workspace' );

    my $role = Socialtext::Role->Member();

    is( $ws->role_for_user( user => $user )->role_id(), $role->role_id(),
        'user has the member role in the workspace' );

    my $log_msg = join ' : ', 'ADD_USER', $ws->workspace_id(),
        $user->user_id(), $role->role_id();
    is( $log_output, $log_msg,
        'user addition was logged' );
}

CHANGE_USER_ROLE:
{
    my $log_output = '';
    Socialtext::Log->new()->log()->add(
        Log::Dispatch::Handle->new(
            name      => 'string-handle',
            min_level => 'info',
            handle    => IO::String->new($log_output),
        )
    );

    my $role = Socialtext::Role->WorkspaceAdmin();
    $ws->assign_role_to_user( user => $user, role => $role );

    is( $ws->role_for_user( user => $user )->role_id(), $role->role_id(),
        'user has the admin role in the workspace' );

    my $log_msg = join ' : ', 'CHANGE_USER_ROLE', $ws->workspace_id(),
        $user->user_id(), $role->role_id();
    is( $log_output, $log_msg,
        'user addition was logged' );
}

REMOVE_USER:
{
    my $log_output = '';
    Socialtext::Log->new()->log()->add(
        Log::Dispatch::Handle->new(
            name      => 'string-handle',
            min_level => 'info',
            handle    => IO::String->new($log_output),
        )
    );

    $ws->remove_user( user => $user );

    ok( ! $ws->has_user( $user ), 'user is no longer a member of the workspace' );

    my $log_msg = join ' : ', 'REMOVE_USER', $ws->workspace_id(),
        $user->user_id();
    is( $log_output, $log_msg,
        'user addition was logged' );
}
