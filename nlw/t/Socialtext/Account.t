#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 43;
use YAML qw/LoadFile/;

BEGIN {
    use_ok( 'Socialtext::Account' );
    use_ok( 'Socialtext::Workspace' );
}
fixtures( 'rdbms_clean' );

is( Socialtext::Account->Count(), 2, 'two accounts in DBMS at start' );
my $test = Socialtext::Account->create( name => 'Test Account' );
isa_ok( $test, 'Socialtext::Account', 'create returns a new Socialtext::Account object' );
users_are($test, []);
is( Socialtext::Account->Count(), 3, 'Now we have three accounts' );

my $unknown = Socialtext::Account->Unknown;
isa_ok( $unknown, 'Socialtext::Account' );
ok( $unknown->is_system_created, 'Unknown account is system-created' );
users_are($unknown, []);

my $socialtext = Socialtext::Account->Socialtext;
isa_ok( $socialtext, 'Socialtext::Account' );
ok( $socialtext->is_system_created, 'Unknown account is system-created' );
users_are($socialtext, ['system-user', 'guest']);

eval { Socialtext::Account->create( name => 'Test Account' ) };
like( $@, qr/already in use/, 'cannot create two accounts with the same name' );

eval { $unknown->update( name => 'new name' ) };
like( $@, qr/cannot change/, 'cannot change the name of a system-created account' );

# Create some test data for the test account
# 3 users, 2 in a workspace, 1 outside the workspace.
{
    my $ws = Socialtext::Workspace->create(
        name       => 'testingspace',
        title      => 'testing',
        account_id => $test->account_id,
    );
    isa_ok( $ws, 'Socialtext::Workspace' );

    for my $n ( 1..3 ) {
        my $user = Socialtext::User->create(
            username      => "dummy$n",
            email_address => "devnull$n\@example.com",
            password      => 'password',
            primary_account_id => 
               ($n != 1 ? $test->account_id : $socialtext->account_id),
        );
        isa_ok( $user, 'Socialtext::User' );
        $ws->add_user( user => $user ) unless $n == 3;;
    }
}

is( $test->workspace_count, 1, 'test account has one workspace' );
is( $test->workspaces->next->name, 'testingspace',
    'testingspace workspace belong to testing account' );
users_are($test, [qw/dummy1 dummy2 dummy3/]);

Account_skins: {
    # set skins
    my $ws      = $test->workspaces->next;
    my $ws_name = $ws->name;
    $ws->update(skin_name => 'reds3');
    my $ws_skin = $ws->skin_name;

    $test = Socialtext::Account->new(name => 'Test Account');
    is($test->skin_name, 's2', 'set the default account skin');

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
        'reds3',
        'reset_skin sets the skins of account workspaces'
    );
}
my $export_file;
Exporting_account_people: {
    $export_file = $test->export( dir => 't' );
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
Socialtext::User->Resolve('dummy1')->delete( force => 1 );
Socialtext::User->Resolve('dummy2')->delete( force => 1 );

Import_account: {
    my $account = Socialtext::Account->import_file( 
        file => $export_file,
        name => 'Imported account',
    );
    is $account->name, 'Imported account', 'new name was set';
    is $account->workspace_count, 0, "import doesn't import workspace data";
    users_are($account, [qw/dummy2 dummy3/]);
}

exit;

sub users_are {
    my $account = shift;
    my $users = shift;

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    # check user count
    # check user list

    is( $account->user_count, scalar(@$users), 
        $account->name . ' account has right number of users' );

    is( join(',', sort map { $_->username } $account->users->all), 
        join(',', sort @$users),
        $account->name . ' account users are correct' );
}
