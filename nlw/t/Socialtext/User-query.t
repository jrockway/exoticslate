#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 36;
fixtures('populated_rdbms');

use Socialtext::User;

{
    my $users = Socialtext::User->All();
    is_deeply(
        [ map { $_->username } $users->all() ],
        [
            ( map { ("devnull$_\@urth.org") } 1 .. 7 ),
             'guest', 'system-user'
        ],
        'All() returns users sorted by name by default',
    );
    is( join(',', map { $_->primary_account->name } $users->all()),
        'Other 1,Other 2,Other 1,Other 2,Other 1,Other 2,Other 1,'
        . 'Socialtext,Socialtext',
        'Primary accounts are set as expected',
    );

    $users = Socialtext::User->All( limit => 2 );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ map { ("devnull$_\@urth.org") } 1 .. 2 ],
        'All() limit of 2',
    );

    $users = Socialtext::User->All( limit => 2, offset => 2 );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ map { ("devnull$_\@urth.org") } 3 .. 4 ],
        'All() limit of 2',
    );

    $users = Socialtext::User->All( sort_order => 'DESC' );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [
            'system-user', 'guest',
            reverse map { ("devnull$_\@urth.org") } 1 .. 7
        ],
        'All() in DESC order',
    );

    $users = Socialtext::User->All( order_by => 'workspace_count' );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [
            'guest', 'system-user',
            map { ("devnull$_\@urth.org") } 7, 6, 4, 5, 3, 2, 1
        ],
        'All() sorted by workspace_count',
    );

    $users = Socialtext::User->All( order_by => 'creation_datetime' );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [
            ( map { ("devnull$_\@urth.org") } 7, 6, 5, 4, 3, 2, 1 ),
            'guest', 'system-user',
        ],
        'All() sorted by creation_datetime',
    );

    $users = Socialtext::User->All( order_by => 'creator' );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [
            ( map { ("devnull$_\@urth.org") } 3, 4, 5, 6, 7, 1, 2 ),
            'guest', 'system-user'
        ],
        'All() sorted by creator',
    );

    my $user = Socialtext::User->Resolve( 'devnull1@urth.org' );
    my $account = Socialtext::Account->new(name => 'Other 1');
    $user->primary_account( $account );
    $users = Socialtext::User->All( 
        order_by   => 'primary_account',
        sort_order => 'desc'
    );
    # Check the t/Fixtures/populated_rdbms/generate script for up-to-date
    # info, but users are added to either the Other 1 or Other 2 accounts.
    is( join(',', map { $_->username } $users->all() ),
        'guest,system-user,devnull4@urth.org,devnull2@urth.org,'
        . 'devnull6@urth.org,devnull1@urth.org,devnull3@urth.org,'
        . 'devnull5@urth.org,devnull7@urth.org',
        'All() sorted by primary account name',
    );
}

{
    # ByAccountId should return users watching either of these criteria:
    # 1) User's primary account is the specified account
    # 2) User is a member of a workspace tied to the specified account

    my $account_id = Socialtext::Account->Socialtext()->account_id();

    my $users = Socialtext::User->ByAccountId(
        account_id => $account_id );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ 'guest', 'system-user' ],
        'ByAccountId() returns users sorted by name by default',
    );

    $users = Socialtext::User->ByAccountId(
        account_id => $account_id,
        limit      => 1,
    );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ 'guest' ],
        'ByAccountId() limit of 2',
    );

    $users = Socialtext::User->ByAccountId(
        account_id => $account_id,
        limit      => 2,
        offset     => 1,
    );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ 'system-user' ],
        'ByAccountId() limit of 2',
    );

    $users = Socialtext::User->ByAccountId(
        account_id => $account_id,
        sort_order => 'DESC',
    );
    is_deeply(
        [ map         { $_->username } $users->all() ],
        [ 'system-user', 'guest' ],
        'ByAccountId() in DESC order',
    );

    $users = Socialtext::User->ByAccountId(
        account_id => $account_id,
        order_by   => 'creation_datetime',
    );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ 'guest', 'system-user' ],
        'ByAccountId() sorted by creation_datetime',
    );

    $users = Socialtext::User->ByAccountId(
        account_id => $account_id,
        order_by   => 'creator',
    );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ 'guest', 'system-user' ],
        'ByAccountId() sorted by creator',
    );

    $users = Socialtext::User->ByAccountId(
        account_id => $account_id,
        order_by   => 'primary_account',
    );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ 'guest', 'system-user' ],
        'ByAccountId() sorted by primary account',
    );
}

{
    # These tests are the same as the previous block, but test the Unknown
    # account, which doesn't have any workspaces.
    my $account_id = Socialtext::Account->Unknown()->account_id();

    my $users = Socialtext::User->ByAccountId(
        account_id => $account_id );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ ],
        'ByAccountId() returns users sorted by name by default',
    );

    $users = Socialtext::User->ByAccountId(
        order_by   => 'creation_datetime',
        account_id => $account_id );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ ],
        'ByAccountId() returns users sorted by creation_datetime',
    );

    $users = Socialtext::User->ByAccountId(
        order_by   => 'creator',
        account_id => $account_id );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ ],
        'ByAccountId() returns users sorted by creator',
    );
}

{
    # These tests are the same as the previous block, but test the Other1
    my $account_id = Socialtext::Account->new(name => 'Other 1')->account_id;

    my $users = Socialtext::User->ByAccountId(
        account_id => $account_id );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ map({ ("devnull$_\@urth.org") } (1, 2, 3, 4, 5, 6, 7)) ],
        'ByAccountId() returns users sorted by name by default',
    );

    $users = Socialtext::User->ByAccountId(
        order_by   => 'creation_datetime',
        account_id => $account_id );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ map({ ("devnull$_\@urth.org") } (7, 6, 5, 4, 3, 2, 1)) ],
        'ByAccountId() returns users sorted by creation_datetime',
    );

    $users = Socialtext::User->ByAccountId(
        order_by   => 'creator',
        account_id => $account_id );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ map({ ("devnull$_\@urth.org") } (3, 4, 5, 6, 7, 1, 2)) ],
        'ByAccountId() returns users sorted by creator',
    );
}

{
    my $ws = Socialtext::Workspace->new( name => 'workspace6' );
    my $users = $ws->users();

    my %roles;
    while ( my $user = $users->next() ) {
        $roles{ $user->username }
            = $ws->role_for_user( user => $user )->name();
    }

    my $ws_id = $ws->workspace_id;

    my $users_with_roles = Socialtext::User->ByWorkspaceIdWithRoles(
        workspace_id => $ws_id );
    is_deeply(
        [
            map { [ $_->[0]->username, $_->[1]->name ] }
                $users_with_roles->all()
        ],
        [ map { my $u = "devnull$_\@urth.org"; [ $u, $roles{$u} ] } 1 .. 7 ],
        'ByWorkspaceIdWithRoles() returns users sorted by name by default',
    );

    $users_with_roles = Socialtext::User->ByWorkspaceIdWithRoles(
        workspace_id => $ws_id,
        limit        => 2,
    );
    is_deeply(
        [
            map { [ $_->[0]->username, $_->[1]->name ] }
                $users_with_roles->all()
        ],
        [ map { my $u = "devnull$_\@urth.org"; [ $u, $roles{$u} ] } 1 .. 2 ],
        'ByWorkspaceIdWithRoles() limit of 2',
    );

    $users_with_roles = Socialtext::User->ByWorkspaceIdWithRoles(
        workspace_id => $ws_id,
        limit        => 2,
        offset       => 2,
    );
    is_deeply(
        [
            map { [ $_->[0]->username, $_->[1]->name ] }
                $users_with_roles->all()
        ],
        [ map { my $u = "devnull$_\@urth.org"; [ $u, $roles{$u} ] } 3 .. 4 ],
        'ByWorkspaceIdWithRoles() limit of 2',
    );

    $users_with_roles = Socialtext::User->ByWorkspaceIdWithRoles(
        workspace_id => $ws_id,
        sort_order   => 'DESC',
    );
    is_deeply(
        [
            map { [ $_->[0]->username, $_->[1]->name ] }
                $users_with_roles->all()
        ],
        [
            reverse map { my $u = "devnull$_\@urth.org"; [ $u, $roles{$u} ] }
                1 .. 7
        ],
        'ByWorkspaceIdWithRoles() in DESC order',
    );

    $users_with_roles = Socialtext::User->ByWorkspaceIdWithRoles(
        workspace_id => $ws_id,
        order_by     => 'creation_datetime',
    );
    is_deeply(
        [
            map { [ $_->[0]->username, $_->[1]->name ] }
                $users_with_roles->all()
        ],
        [ map { my $u = "devnull$_\@urth.org"; [ $u, $roles{$u} ] } 7, 6, 5, 4, 3, 2, 1 ],
        'ByWorkspaceIdWithRoles() sorted by creation_datetime',
    );

    $users_with_roles = Socialtext::User->ByWorkspaceIdWithRoles(
        workspace_id => $ws_id,
        order_by     => 'creator',
    );
    is_deeply(
        [
            map { [ $_->[0]->username, $_->[1]->name ] }
                $users_with_roles->all()
        ],
        [
            map { my $u = "devnull$_\@urth.org"; [ $u, $roles{$u} ] } 3, 4, 5,
            6, 7, 1, 2
        ],
        'ByWorkspaceIdWithRoles() sorted by creator',
    );
}

{
    is(
        Socialtext::User->CountByUsername( username => 'urth' ), 7,
        'seven users have usernames matching "%urth%"'
    );

    my $users = Socialtext::User->ByUsername( username => 'urth' );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ map { ("devnull$_\@urth.org") } 1 .. 7 ],
        'ByUsername() returns users sorted by name by default',
    );

    $users = Socialtext::User->ByUsername( username => 'urth',
        limit => 2 );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ map { ("devnull$_\@urth.org") } 1 .. 2 ],
        'ByUsername() limit of 2',
    );

    $users = Socialtext::User->ByUsername( username => 'urth',
        limit => 2, offset => 2 );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ map { ("devnull$_\@urth.org") } 3 .. 4 ],
        'ByUsername() limit of 2',
    );

    $users = Socialtext::User->ByUsername( username => 'urth',
        sort_order => 'DESC' );
    is_deeply(
        [ map         { $_->username } $users->all() ],
        [ reverse map { ("devnull$_\@urth.org") } 1 .. 7 ],
        'ByUsername() in DESC order',
    );

    $users = Socialtext::User->ByUsername( username => 'urth',
        order_by => 'workspace_count' );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ map { ("devnull$_\@urth.org") } 7, 6, 4, 5, 3, 2, 1 ],
        'ByUsername() sorted by workspace_count',
    );

    $users = Socialtext::User->ByUsername( username => 'urth',
        order_by => 'creation_datetime' );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ map { ("devnull$_\@urth.org") } 7, 6, 5, 4, 3, 2, 1 ],
        'ByUsername() sorted by creation_datetime',
    );

    $users = Socialtext::User->ByUsername( username => 'urth',
        order_by => 'creator' );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ map { ("devnull$_\@urth.org") } 3, 4, 5, 6, 7, 1, 2 ],
        'ByUsername() sorted by creator',
    );
}
