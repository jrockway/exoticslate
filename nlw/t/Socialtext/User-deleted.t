#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 5;
fixtures('populated_rdbms');

use Socialtext::User;
use Socialtext::UserId;

{
    my $users = Socialtext::User->All();
    is_deeply(
        [ map { $_->username } $users->all() ],
        [
            ( map { ("devnull$_\@urth.org") } 1 .. 7 ),
             'guest', 'system-user'
        ],
        'Got the minimum 9 users this fixture starts with.',
    );
}

# populate a user that doesn't currently exist, even though it uses a
# known driver.
Socialtext::UserId->create(
    system_unique_id => 99,
    driver_key       => 'Default',
    driver_unique_id => "I met a man who wasn't there",
    driver_username  => "Nemo",
);

{
    is (Socialtext::User->Count, 10, "New user added only to UserId, simulating adding and deleting from the store.");
    my $nemo = Socialtext::User->new( user_id => 99 );
    is ($nemo->username, 'Nemo', "Nemo was found, no error.");
    is ($nemo->first_name, 'Deleted', "But he's still deleted.");
}

{
    my $nonexistent = Socialtext::User->new( username => 'dracula' );
    is ($nonexistent, undef, "For users that didn't exist, they're still undef.");
}
