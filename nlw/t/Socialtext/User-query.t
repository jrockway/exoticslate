#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 27;
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
}

{
    my $account_id = Socialtext::Account->Socialtext()->account_id();

    my $users = Socialtext::User->ByAccountId(
        account_id => $account_id );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ map { ("devnull$_\@urth.org") } 1 .. 7 ],
        'ByAccountId() returns users sorted by name by default',
    );

    $users = Socialtext::User->ByAccountId(
        account_id => $account_id,
        limit      => 2,
    );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ map { ("devnull$_\@urth.org") } 1 .. 2 ],
        'ByAccountId() limit of 2',
    );

    $users = Socialtext::User->ByAccountId(
        account_id => $account_id,
        limit      => 2,
        offset     => 2,
    );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ map { ("devnull$_\@urth.org") } 3 .. 4 ],
        'ByAccountId() limit of 2',
    );

    $users = Socialtext::User->ByAccountId(
        account_id => $account_id,
        sort_order => 'DESC',
    );
    is_deeply(
        [ map         { $_->username } $users->all() ],
        [ reverse map { ("devnull$_\@urth.org") } 1 .. 7 ],
        'ByAccountId() in DESC order',
    );

    $users = Socialtext::User->ByAccountId(
        account_id => $account_id,
        order_by   => 'creation_datetime',
    );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ map { ("devnull$_\@urth.org") } 7, 6, 5, 4, 3, 2, 1 ],
        'ByAccountId() sorted by creation_datetime',
    );

    $users = Socialtext::User->ByAccountId(
        account_id => $account_id,
        order_by   => 'creator',
    );
    is_deeply(
        [ map { $_->username } $users->all() ],
        [ map { ("devnull$_\@urth.org") } 3, 4, 5, 6, 7, 1, 2 ],
        'ByAccountId() sorted by creator',
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
