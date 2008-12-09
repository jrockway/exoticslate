#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext;
fixtures( 'db' );
BEGIN {
    plan tests => 7;

    use_ok 'Socialtext::User';
    use_ok 'Socialtext::Pluggable::Adapter';
}

use Socialtext::CLI;

my $t = time;

# the plan: check if the plugin is ...
# enabled via both primary and secondary accounts (user a)
# enabled via primary (user b)
# enabled via secondary (user c)
# disabled via both primary and secondary (user d)

my $exists = Socialtext::Pluggable::Adapter->plugin_exists('test');
ok $exists, 'the "test" plugin exists';

my $status;
{
    no warnings qw(once redefine);
    *Socialtext::CLI::_exit = sub { $status = shift };
}

sub st_admin {
    my $args = shift;
    my @args = split(/\s+/,$args);
    Socialtext::CLI->new(argv => [@args])->run();
    die "CLI failed" if $status;
}

st_admin("create-account --name acct_a_$t");
st_admin("create-account --name acct_b_$t");

st_admin("create-workspace --account acct_a_$t --name ws_a --title ws_a");
st_admin("create-workspace --account acct_b_$t --name ws_b --title ws_a");

st_admin("enable-plugin --account acct_a_$t --plugin test");

st_admin("create-user --email a$t\@d.d --password password");
st_admin("create-user --email b$t\@d.d --password password");
st_admin("create-user --email c$t\@d.d --password password");
st_admin("create-user --email d$t\@d.d --password password");

st_admin("set-user-account --email a$t\@d.d --account acct_a_$t");
st_admin("add-member --email a$t\@d.d --workspace ws_a");
st_admin("set-user-account --email b$t\@d.d --account acct_a_$t");
st_admin("add-member --email b$t\@d.d --workspace ws_b");
st_admin("set-user-account --email c$t\@d.d --account acct_b_$t");
st_admin("add-member --email c$t\@d.d --workspace ws_a");
st_admin("set-user-account --email d$t\@d.d --account acct_b_$t");
st_admin("add-member --email d$t\@d.d --workspace ws_b");


my $user_a = Socialtext::User->new(username => "a$t\@d.d");
ok $user_a->can_use_plugin('test'), 'enabled via both';

my $user_b = Socialtext::User->new(username => "b$t\@d.d");
ok $user_b->can_use_plugin('test'), 'enabled via primary';

my $user_c = Socialtext::User->new(username => "c$t\@d.d");
ok $user_c->can_use_plugin('test'), 'enabled via secondary';

my $user_d = Socialtext::User->new(username => "d$t\@d.d");
ok !$user_d->can_use_plugin('test'), 'not enabled in either primary or secondary';

