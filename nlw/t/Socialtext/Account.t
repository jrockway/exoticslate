#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 16;

BEGIN {
    use_ok( 'Socialtext::Account' );
    use_ok( 'Socialtext::Workspace' );
}
fixtures( 'rdbms_clean' );

is( Socialtext::Account->Count(), 2, 'two accounts in DBMS at start' );
my $test = Socialtext::Account->create( name => 'Test Account' );
isa_ok( $test, 'Socialtext::Account', 'create returns a new Socialtext::Account object' );
is( Socialtext::Account->Count(), 3, 'Now we have three accounts' );

my $unknown = Socialtext::Account->Unknown;
isa_ok( $unknown, 'Socialtext::Account' );
ok( $unknown->is_system_created, 'Unknown account is system-created' );

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
            account_id    => Socialtext::Account->Socialtext()->account_id(),
        );
        isa_ok( $user, 'Socialtext::User' );

        $ws->add_user( user => $user );
        # REVIEW: It'd be nice if add_user had a meaningful return value we
        # could check.
    }
}

is( $test->workspace_count, 1, 'test account has one workspace' );
is( $test->workspaces->next->name, 'testingspace',
    'testingspace workspace belong to testing account' );

is( $test->user_count, 2, 'test account has two users' );
is( $test->users->next->username, 'dummy1',
    'test account users includes dummy1' );
