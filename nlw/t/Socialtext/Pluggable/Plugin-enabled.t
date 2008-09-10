#!perl
# @COPYRIGHT@
use warnings;
use strict;

use Test::More tests => 8;
use mocked qw/Socialtext::SQL sql_ok sql_mock_result/;
use mocked 'Socialtext::Workspace';
use mocked 'Socialtext::User';

BEGIN {
    use_ok 'Socialtext::Pluggable::Adapter';
}

my $user = Socialtext::User->new(user_id => 43);

# Start off with the plugin not being installed/configured
{
    no warnings qw(redefine once);
    *Socialtext::Pluggable::Adapter::plugin_exists = sub { 0 };
}

my $en = Socialtext::Pluggable::Adapter->PluginEnabledForUser('foobar',$user);
ok !$en, "not enabled when plugin doesn't exist";


# Make the plugin appear to exist, the code should now query the DB
# to see if it's enabled for a user.

{
    no warnings qw(redefine once);
    *Socialtext::Pluggable::Adapter::plugin_exists = sub { 1 };
}

my $expected_sql = <<SQL;
    SELECT 1 FROM user_account
    WHERE system_unique_id = ?
      AND EXISTS (
        SELECT 1 
        FROM account_plugin 
        WHERE plugin = ? AND (
            account_id = primary_account_id OR
            account_id = secondary_account_id
        )
      )
    LIMIT 1
SQL

sql_mock_result([]);
$en = Socialtext::Pluggable::Adapter->PluginEnabledForUser('foobar',$user);
sql_ok(
    sql => $expected_sql,
    args => [43, 'foobar'],
);
ok !$en, "disabled when query doesn't return any rows";

sql_mock_result([1]);
$en = Socialtext::Pluggable::Adapter->PluginEnabledForUser('foobar',$user);
sql_ok(
    sql => $expected_sql,
    args => [43, 'foobar'],
);
ok $en, "enabled when configured in the db";
