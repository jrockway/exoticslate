#!perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext tests => 8;
fixtures(qw( clean db ));

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

$user->primary_account( Socialtext::Account->Unknown() );

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

    # When we add a user to thier first workspace, we reassign thier account.
    is( $user->primary_account->name, 'Socialtext', 'user account changed.' );

    my $log_msg = 'ASSIGN,USER_ROLE,role:'
        . $role->name
        . ',user:'
        . $user->username . '('
        . $user->user_id . '),'
        . 'workspace:'
        . $ws->name . '('
        . $ws->workspace_id . '),';

    like( $log_output, qr{\Q$log_msg\E\[[\d\.]+\]},
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

    my $log_msg = 'CHANGE,USER_ROLE,role:'
        . $role->name
        . ',user:'
        . $user->username . '('
        . $user->user_id . '),'
        . 'workspace:'
        . $ws->name . '('
        . $ws->workspace_id . '),';

    like( $log_output, qr{\Q$log_msg\E\[[\d\.]+\]},
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

    my $log_msg = 'REMOVE,USER_ROLE,'
        . 'user:'
        . $user->username . '('
        . $user->user_id . '),'
        . 'workspace:'
        . $ws->name . '('
        . $ws->workspace_id . '),';

    like( $log_output, qr{\Q$log_msg\E\[[\d\.]+\]},
        'user addition was logged' );
}
