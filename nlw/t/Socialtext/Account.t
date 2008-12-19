#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 83;
use Test::Socialtext::User;
use Test::Exception;
use YAML qw/LoadFile/;

BEGIN { push @INC, 't/share/plugin/fakeplugin/lib' }

use Socialtext::Pluggable::Plugin::FakePlugin;

BEGIN {
    use_ok( 'Socialtext::Account' );
    use_ok( 'Socialtext::Workspace' );
}
fixtures( 'rdbms_clean' );

is( Socialtext::Account->Count(), 4, 'three accounts in DBMS at start' );
my $test = Socialtext::Account->create( name => 'Test Account' );
isa_ok( $test, 'Socialtext::Account', 'create returns a new Socialtext::Account object' );
users_are($test, []);
is( Socialtext::Account->Count(), 5, 'Now we have four accounts' );

my $unknown = Socialtext::Account->Unknown;
isa_ok( $unknown, 'Socialtext::Account' );
ok( $unknown->is_system_created, 'Unknown account is system-created' );
users_are($unknown, []);

my $deleted = Socialtext::Account->Deleted;
isa_ok( $deleted, 'Socialtext::Account' );
ok( $deleted->is_system_created, 'Deleted account is system-created' );
users_are($deleted, []);

my $socialtext = Socialtext::Account->Socialtext;
isa_ok( $socialtext, 'Socialtext::Account' );
ok( $socialtext->is_system_created, 'Unknown account is system-created' );
users_are($socialtext, ['system-user', 'guest']);

eval { Socialtext::Account->create( name => 'Test Account' ) };
like( $@, qr/already in use/, 'cannot create two accounts with the same name' );

eval { $unknown->update( name => 'new name' ) };
like( $@, qr/cannot change/, 'cannot change the name of a system-created account' );

my $ws = Socialtext::Workspace->create(
    name       => 'testingspace',
    title      => 'testing',
    account_id => $test->account_id,
);
isa_ok( $ws, 'Socialtext::Workspace' );

# Create some test data for the test account
# 3 users, 2 in a workspace (1 hidden, 1 visible), 1 outside the workspace.
{
    for my $n ( 1..3 ) {
        my $user = Socialtext::User->create(
            username      => "dummy$n",
            email_address => "devnull$n\@example.com",
            password      => 'password',
            primary_account_id => 
               ($n != 1 ? $test->account_id : $socialtext->account_id),
        );
        isa_ok( $user, 'Socialtext::User' );

        $ws->add_user( user => $user ) unless $n == 3;
    }
}

Rudimentary_Plugin_Test: {
   $socialtext->enable_plugin( 'dashboard' );
   is('1', $socialtext->is_plugin_enabled('dashboard'), 'dashboard enabled.');
   my %enabled = map { $_ => 1 } $socialtext->plugins_enabled;
   is_deeply( \%enabled, { widgets => 1, dashboard => 1 }, 'enabled.');
   $socialtext->disable_plugin( 'dashboard' );
   is('0', $socialtext->is_plugin_enabled('dashboard'), 'dashboard disabled.');
}

is( $test->workspace_count, 1, 'test account has one workspace' );
is( $test->workspaces->next->name, 'testingspace',
    'testingspace workspace belong to testing account' );
users_are($test, [qw/dummy1 dummy2 dummy3/], 0);
users_are($test, [qw/dummy2 dummy3/], 1);

Rename_account: {
    my $new_name = 'Ronwell Quincy Dobbs';
    my $account = Socialtext::Account->create(name => 'ronnie dobbs');
    $account->update(name => $new_name);
    is $account->name, $new_name, 'account name was changed';
    $account = Socialtext::Account->new(name => $new_name);
    is $account->name, $new_name,
        'account name was changed after db round-trip';
    dies_ok { $account->update(name => 'Socialtext') }
        'cannot rename account to an existing name';
    is $account->name, $new_name,
        'account name unchanged after attempt to duplicate rename';
}

SKIP: {
    eval { require Socialtext::People::Profile }
        or skip("The People plugin is not available!", 2);

    my $dummy3 = Socialtext::User->new( username => 'dummy3' );
    my $profile = Socialtext::People::Profile->GetProfile( $dummy3->user_id );
    $profile->is_hidden(1);
    $profile->save;

    users_are($test, [qw/dummy2/], 1, 1);

    $profile->is_hidden(0);
    $profile->save;
}

Account_skins: {
    # set skins
    my $ws      = $test->workspaces->next;
    my $ws_name = $ws->name;
    $ws->update(skin_name => 'reds3');
    my $ws_skin = $ws->skin_name;

    $test = Socialtext::Account->new(name => 'Test Account');
    is($test->skin_name, 's3', 'the default skin for accounts');

    $test->update(skin_name => 's2');
    is($test->skin_name, 's2', 'set the account skin');
    is(
        Socialtext::Workspace->new(name => $ws_name)->skin_name,
        $ws_skin,
        'updating account skin does not change workspace skins'
    );
    my $new_test = Socialtext::Account->new(name => 'Test Account');
    is($new_test->skin_name, 's2', 'set the account skin');

    # reset account and workspace skins
    $new_test->reset_skin('reds3');

    $test = Socialtext::Account->new(name => 'Test Account');
    is(
        $test->skin_name,
        'reds3',
        'reset_skin sets the skins of account workspaces'
    );
    is(
        Socialtext::Workspace->new(name => $ws_name)->skin_name,
        '',
        'reset_skin sets the skins of account workspaces'
    );

    is_deeply( [], $test->custom_workspace_skins, 'custom workspace skins is empty.');
    $ws->update( skin_name => 's3' );
    is_deeply( ['s3'], $test->custom_workspace_skins, 'custom workspace skins updated.');
    my $mess = $test->custom_workspace_skins( include_workspaces => 1 );
    is( $ws_name, $mess->{s3}[0]{name}, 'custom skins with workspaces.');
}

use Test::MockObject;
my $mock_adapter = Test::MockObject->new({});
$mock_adapter->mock('hook', sub {});
my $mock_hub = Test::MockObject->new({});
$mock_hub->mock('pluggable', sub { $mock_adapter });

my $export_file;
Exporting_account_people: {
    $export_file = $test->export( dir => 't', hub => $mock_hub );
    ok -e $export_file, "exported file $export_file exists";
    my $data = LoadFile($export_file);
    is $data->{name}, 'Test Account', 'name is in export';
    is $data->{is_system_created}, 0, 'is_system_created is in export';
    is scalar(@{ $data->{users} }), 2, 'users exported in test account';
    is $data->{users}[0]{username}, 'dummy2', 'user 1 username';
    is $data->{users}[0]{email_address}, 'devnull2@example.com', 'user 1 email';
    is $data->{users}[1]{username}, 'dummy3', 'user 2 username';
    is $data->{users}[1]{email_address}, 'devnull3@example.com', 'user 2 email';
}

# Now blow the account and users away for the re-import
Test::Socialtext::User->delete_recklessly( Socialtext::User->Resolve('dummy1') );
Test::Socialtext::User->delete_recklessly( Socialtext::User->Resolve('dummy2') );

Import_account: {
    my $account = Socialtext::Account->import_file( 
        file => $export_file,
        name => 'Imported account',
        hub => $mock_hub,
    );
    is $account->name, 'Imported account', 'new name was set';
    is $account->workspace_count, 0, "import doesn't import workspace data";
    users_are($account, [qw/dummy2 dummy3/]);
}

Wierd_corner_case: {
    my $user = Socialtext::User->create(
            username      => "dummy1234",
            email_address => "devnull1234\@example.com",
            password      => 'password',
            primary_account_id => $unknown->account_id
    );
    isa_ok($user, 'Socialtext::User');
    $ws->add_user( user => $user );
    is($user->primary_account->name, $test->name);
}

Plugins_enabled_for_all: {
    Socialtext::Account->DisablePluginForAll('fakeplugin');

    my $account1 = Socialtext::Account->create(name => "new_account_$^T");
    ok !$account1->is_plugin_enabled('fakeplugin'),
       'fakeplugin is not enabled by default';

    Socialtext::Account->EnablePluginForAll('fakeplugin');
    ok Socialtext::SystemSettings::get_system_setting('fakeplugin-enabled-all'),
       'System entry created for enabled plugin';
    ok $account1->is_plugin_enabled('fakeplugin'),
        'fakeplugin is now after EnablePluginForAll';

    my $account2 = Socialtext::Account->create(name => "newer_account_$^T");
    ok $account2->is_plugin_enabled('fakeplugin'),
       'fakeplugin is enabled for new accounts after EnablePluginForAll';
}

exit;

sub users_are {
    my $account = shift;
    my $users = shift;
    my $primary_only = shift;
    my $exclude_hidden_people = shift;

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    # check user count
    # check user list

    is( $account->user_count($primary_only, $exclude_hidden_people), scalar(@$users), 
        $account->name . ' account has right number of users' );

    for my $order_by (qw( username creation_datetime creator )) {
        my $mc = $account->users(
            primary_only => $primary_only,
            exclude_hidden_people => $exclude_hidden_people,
            order_by => $order_by,
        );
        is( join(',', sort map { $_->username } $mc->all), 
            join(',', sort @$users),
            $account->name . ' account users are correct' );
    }
}
