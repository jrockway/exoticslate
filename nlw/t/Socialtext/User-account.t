#!perl
# @COPYRIGHT@
use warnings;
use strict;
use Test::Socialtext tests => 31;
fixtures('db');
use t::Socialtext::st_admin;

use Socialtext::User;
use Socialtext::Account;

my $now = time;

st_admin("create-account --name acct_a_$now");
my $acct_a = Socialtext::Account->new(name => "acct_a_$now");
my $user1email = "user_1_$now\@ken.socialtext.net";
st_admin("create-user --username user_1_$now --email $user1email --password foobar");
st_admin("set-user-account --email $user1email --account acct_a_$now");

Check_just_one_account: {
    my $user = Socialtext::User->new(email_address => $user1email);
    ok $user->primary_account;
    is $user->primary_account->account_id, $acct_a->account_id;
    is $user->primary_account_id, $acct_a->account_id;
    my @acct_list = $user->accounts();
    is scalar(@acct_list), 1, "just one account";
    isa_ok $acct_list[0], 'Socialtext::Account';
    is $acct_list[0]->account_id, $acct_a->account_id;
}

st_admin("create-account --name acct_b_$now");
my $acct_b = Socialtext::Account->new(name => "acct_b_$now");
st_admin("create-workspace --name ws_b_$now --title ws_b_$now --account acct_b_$now");
st_admin("add-member --workspace ws_b_$now --email $user1email");

Two_accounts_now: {
    my $user = Socialtext::User->new(email_address => $user1email);
    is $user->primary_account_id, $acct_a->account_id;
    my @acct_list = $user->accounts();
    is scalar(@acct_list), 2, 'two accounts now';
    is $acct_list[0]->account_id, $acct_a->account_id;
    is $acct_list[1]->account_id, $acct_b->account_id;
}

test_plugin_associations: {
    st_admin("disable-plugin --plugin test --account acct_a_$now");
    st_admin("disable-plugin --plugin test --account acct_b_$now");

    no_plugin_association: {
        my $user = Socialtext::User->new(email_address => $user1email);
        my $acct_list = $user->accounts(plugin => 'test');
        is_deeply $acct_list, [], 'no accounts for "test" plugin';
    }

    st_admin("enable-plugin --plugin test --account acct_a_$now");

    one_plugin_association: {
        my $user = Socialtext::User->new(email_address => $user1email);
        my @acct_list = $user->accounts();
        is scalar(@acct_list), 2, 'two accounts now';
        is $acct_list[0]->account_id, $acct_a->account_id;
    }

    st_admin("enable-plugin --plugin test --account acct_b_$now");

    two_plugin_associations: {
        my $user = Socialtext::User->new(email_address => $user1email);
        is $user->primary_account_id, $acct_a->account_id;
        my @acct_list = $user->accounts();
        is scalar(@acct_list), 2, 'two accounts now';
        is $acct_list[0]->account_id, $acct_a->account_id;
        is $acct_list[1]->account_id, $acct_b->account_id;
    }
}

st_admin("set-user-account --email $user1email --account acct_b_$now");

Back_to_one_account: {
    my $user = Socialtext::User->new(email_address => $user1email);
    is $user->primary_account_id, $acct_b->account_id;
    my @acct_list = $user->accounts();
    is scalar(@acct_list), 1, 'back to one account';
    is $acct_list[0]->account_id, $acct_b->account_id;
}


