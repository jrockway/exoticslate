#!/usr/bin/perl
use warnings;
use strict;

# This test was created to aid in refactoring the 'account_user' view into a
# materialized view, but the mat-view turned out to be too slow.  It should
# capture the business logic of "if a user's in an workspace, they're also in
# that workspace's account".

use Test::Socialtext tests => 28;
use Socialtext::SQL qw/get_dbh/;
use Socialtext::User;
use Socialtext::Account;
use Socialtext::Workspace;

fixtures( 'db' );

my($user, $user_id, $user2, $user2_id);
my($ws, $ws_id);
my($default, $default_id);
my($acct, $acct_id, $acct2, $acct2_id);

setup: {
    $user = Socialtext::User->create(
        username => "user $^T",
        email_address => "user$^T\@ken.socialtext.net",
        first_name => "User",
        last_name => "$^T",
    );
    ok $user;
    $user_id = $user->user_id;
    ok $user_id;

    $user2 = Socialtext::User->create(
        username => "user2 $^T",
        email_address => "user2$^T\@ken.socialtext.net",
        first_name => "User2",
        last_name => "$^T",
    );
    ok $user2;
    $user2_id = $user2->user_id;
    ok $user2_id;

    $acct = Socialtext::Account->create(
        name => "Account $^T"
    );
    ok $acct;
    $acct_id = $acct->account_id;
    ok $acct_id;

    $acct2 = Socialtext::Account->create(
        name => "Account2 $^T"
    );
    ok $acct2;
    $acct2_id = $acct2->account_id;
    ok $acct2_id;

    $default = Socialtext::Account->Default();
    ok $default;
    $default_id = $default->account_id;
    ok $default_id;

    $ws = Socialtext::Workspace->create(
        skip_default_pages => 1,
        name => "ws_$^T",
        title => "Workspace $^T",
        account_id => $acct_id,
    );
    ok $ws;
    $ws_id = $ws->workspace_id;
    ok $ws_id;
}

END {
    $ws->delete() if $ws;
    $acct->delete() if $acct;
    $acct2->delete() if $acct2;
}

sub membership_is {
    my $expected = shift;
    my $name = shift;

    local $Test::Bulder::Level = ($Test::Bulder::Level||0) + 1;

    my $dbh = get_dbh;

    my $membership_sth = $dbh->prepare(q{
        SELECT account_id, user_id FROM account_user
        WHERE user_id IN (?,?)
        ORDER BY user_id, account_id
    });
    $membership_sth->execute($user_id, $user2_id);
    my $got = $membership_sth->fetchall_arrayref;
    use Data::Dumper;
    is_deeply $got, $expected, $name
        or warn Dumper($got);
}

baseline: {
    membership_is [
        [$default_id, $user_id ],
        [$default_id, $user2_id],
    ], 'baseline membership is default account';
}

workspace_membership: {
    $ws->add_user(user => $user);
    membership_is [
        [$default_id, $user_id ],
        [$acct_id,    $user_id ],
        [$default_id, $user2_id],
    ], 'adding a user to a workspace adds an account membership';

    my $role = Socialtext::Role->new(name => 'impersonator');
    $ws->assign_role_to_user(user => $user, role => $role);
    membership_is [
        [$default_id, $user_id ],
        [$acct_id,    $user_id ],
        [$default_id, $user2_id],
    ], 'changing roles maintains the membership';

    $ws->remove_user(user => $user);
    membership_is [
        [$default_id, $user_id ],
        [$default_id, $user2_id],
    ], 'removing a user to a workspace removes the account membership';
}

workspace_changes_account: {
    $ws->add_user(user => $user2);
    membership_is [
        [$default_id, $user_id ],
        [$default_id, $user2_id],
        [$acct_id,    $user2_id],
    ], 'adding a user to a workspace adds an account membership';

    my $old_ws = $ws;

    change_workspace_account($ws,$acct2);

    $ws = Socialtext::Workspace->new(workspace_id => $ws_id);
    ok $ws;
    isnt $ws,$old_ws;
    is $ws->account_id, $acct2_id;

    membership_is [
        [$default_id, $user_id ],
        [$default_id, $user2_id],
        [$acct2_id,   $user2_id],
    ], 'changing the workspace\'s account changes the user\'s membership';

    $ws->remove_user(user => $user2);
    membership_is [
        [$default_id, $user_id ],
        [$default_id, $user2_id],
    ], 'removing a user to a workspace removes the account membership';
}

primary_account_changes_memberhip: {
    $ws->add_user(user => $user2);
    membership_is [
        [$default_id, $user_id ],
        [$default_id, $user2_id],
        [$acct2_id,   $user2_id],
    ], 'adding a user to a workspace adds an account membership';

    $user2->primary_account($acct);
    membership_is [
        [$default_id, $user_id ],
        [$acct_id,    $user2_id],
        [$acct2_id,   $user2_id],
    ], 'changing the primary account changes the account membership';

    $user->primary_account($acct2);
    $user2->primary_account($acct2);
    membership_is [
        [$acct2_id, $user_id ],
        [$acct2_id, $user2_id],
        [$acct2_id, $user2_id],
    ], 'duplicate entries are ok';

    $user2->primary_account($acct);
    membership_is [
        [$acct2_id, $user_id ],
        [$acct_id,  $user2_id],
        [$acct2_id, $user2_id],
    ], 'user 2 goes back to account 1';
}

deleting_workspace_removes_membership: {
    $ws->delete();
    $ws = undef;

    membership_is [
        [$acct2_id, $user_id ],
        [$acct_id,  $user2_id],
    ], 'deleting workspace removes account membership';
}

deleting_account_removes_membership: {
    $acct->delete();
    $acct = undef;

    membership_is [
        [$acct2_id, $user_id ],
    ], 'deleting account removes account membership';
}

sub change_workspace_account {
    my ($w, $a) = @_;
    # XXX: currently there's no API to change which account a workspace lives in
    my $dbh = get_dbh;
    my $sth = $dbh->prepare(
        q{UPDATE "Workspace" SET account_id = ? WHERE workspace_id = ?});
    $sth->execute($a->account_id, $w->workspace_id);
}

