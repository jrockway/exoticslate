#!perl
# @COPYRIGHT@
use Test::Socialtext tests => 8;

use strict;
use warnings;
use Socialtext::User;

fixtures('clean', 'workspaces');

BEGIN { use_ok('Socialtext::Search::Set') }

my $devnull1
    = Socialtext::User->new( email_address => 'devnull1@socialtext.com' );
my $devnull2
    = Socialtext::User->new( email_address => 'devnull2@socialtext.com' );

Reuse_name_between_users: {
    my $devnull1_set = Socialtext::Search::Set->create(
        name => 'xyzzy',
        user => $devnull1 );
    isa_ok( $devnull1_set, 'Socialtext::Search::Set' );

    my $devnull2_set = Socialtext::Search::Set->create(
        name => 'xyzzy',
        user => $devnull2 );
    isa_ok( $devnull2_set, 'Socialtext::Search::Set' );

    isnt( $devnull1_set->search_set_id, $devnull2_set->search_set_id,
        'Different user sets with the same name have distinct ids.' );
}

List_workspaces: {
    my $devnull1_set = Socialtext::Search::Set->new(
        name => 'xyzzy',
        user => $devnull1 );
    $devnull1_set->add_workspace_name($_) for qw( foobar admin public );
    my @workspace_names = $devnull1_set->workspace_names->all;
    is( scalar @workspace_names, 3, "There are 3 workspace names.\n" );

    foreach my $name (qw( foobar admin public )) {
        is((scalar grep { $_ eq $name } @workspace_names),
            1, "$name is in the list.\n");
    }
}
