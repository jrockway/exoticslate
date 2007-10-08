#! perl -w
# @COPYRIGHT@
use warnings;
use strict;

use Test::Socialtext tests => 4;

fixtures('foobar', 'help');

use Socialtext::User;
use Socialtext::Ceqlotron;
use_ok( 'Socialtext::Search', 'search_on_behalf' );

$ENV{NLW_APPCONFIG} = 'ceqlotron_synchronous=1';
warn "# Running this ceqlotron queue.  This may take a minute or two.\n";
Socialtext::Ceqlotron::run_current_queue();

my $user = Socialtext::User->Guest;

eval {
    search_on_behalf( 'help', 'link workspaces:foobar,help', '_', $user );
};
isa_ok( $@, 'Socialtext::Exception::Auth', "auth exception on search foobar" );

HIT: {
    my @hits;
    eval {
        @hits
            = search_on_behalf( 'help', 'link workspaces:foobar,help', '_',
            $user, sub { }, sub { } );
    };
    is( $@, '', "No exceptions thrown." );
    for my $hit (@hits) {
        if ($hit->workspace_name eq 'foobar') {
            fail('No foobar hits for guest user.');
            last HIT;
        }
    }
    pass('No foobar hits for guest user.');
}
