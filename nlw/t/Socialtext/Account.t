#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 24;

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

{
    my $ws = Socialtext::Workspace->create(
        name       => 'testingspace',
        title      => 'testing',
        account_id => $test->account_id,
    );
    isa_ok( $ws, 'Socialtext::Workspace' );

    for my $n ( 1..2 ) {
        my $user = Socialtext::User->create(
            username      => "dummy$n",
            email_address => "devnull$n\@example.com",
            password      => 'password',
            primary_account_id => $socialtext->account_id(),
        );
        isa_ok( $user, 'Socialtext::User' );
        $ws->add_user( user => $user );
    }
}

is( $test->workspace_count, 1, 'test account has one workspace' );
is( $test->workspaces->next->name, 'testingspace',
    'testingspace workspace belong to testing account' );
users_are($test, [qw/dummy1 dummy2/]);

exit;

sub users_are {
    my $account = shift;
    my $users = shift;

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    # check user count
    # check user list

    is( $account->user_count, scalar(@$users), 
        $account->name . ' account has two users' );

    is( join(',', sort map { $_->username } $account->users->all), 
        join(',', sort @$users),
        $account->name . ' account users are correct' );
}
