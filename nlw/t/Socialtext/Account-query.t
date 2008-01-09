#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 18;
use Test::More;
fixtures( 'populated_rdbms' );

BEGIN {
    use_ok( 'Socialtext::Account' );
}


my $accounts = Socialtext::Account->All();
is_deeply(
    [ map { $_->name } $accounts->all() ],
    [ 'Other 1', 'Other 2', 'Socialtext', 'Unknown' ],
    'All() returns accounts sorted by name by default',
);

$accounts = Socialtext::Account->All( limit => 2 );
is_deeply(
    [ map { $_->name } $accounts->all() ],
    [ 'Other 1', 'Other 2' ],
    'All() limit of 2',
);

$accounts = Socialtext::Account->All( limit => 2, offset => 1 );
is_deeply(
    [ map { $_->name } $accounts->all() ],
    [ 'Other 2', 'Socialtext' ],
    'All() limit of 2, offset of 1',
);

$accounts = Socialtext::Account->All( sort_order => 'DESC' );
is_deeply(
    [ map { $_->name } $accounts->all() ],
    [ 'Unknown', 'Socialtext', 'Other 2', 'Other 1' ],
    'All() sorted in DESC order',
);

$accounts = Socialtext::Account->All( order_by => 'user_count' );
is_deeply(
    [ map { $_->name } $accounts->all() ],
    [ 'Unknown', 'Other 1', 'Other 2', 'Socialtext' ],
    'All() sorted in order of user_count',
);

$accounts = Socialtext::Account->All( order_by => 'workspace_count' );
is_deeply(
    [ map { $_->name } $accounts->all() ],
    [ 'Unknown', 'Other 1', 'Other 2', 'Socialtext' ],
    'All() sorted in order of workspace_count',
);

Search: {
    my @search_tests = (
        {
            desc => 'search',
            args => { name => 'Social' },
            results => ['Socialtext'],
        },
        {
            desc => 'search - case sensitive',
            args => { name => 'social' },
            results => [],
        },
        {
            desc => 'search - case insensitive',
            args => { name => 'social', case_insensitive => 1 },
            results => ['Socialtext'],
        },
        {
            desc => 'search - case insensitive',
            args => { name => 'sOcIaL', case_insensitive => 1 },
            results => ['Socialtext'],
        },
        {
            desc => 'search - case insensitive',
            args => { name => 'THER', case_insensitive => 1 },
            results => ['Other 1', 'Other 2'],
        },
    );
    for my $s (@search_tests) {
        $accounts = Socialtext::Account->ByName( %{ $s->{args} } );
        is_deeply(
            [ map { $_->name } $accounts->all() ],
            $s->{results},
            $s->{desc},
        );
        is( Socialtext::Account->CountByName( %{ $s->{args} } ), 
            scalar(@{ $s->{results} }), 
            'count matches'
        );
    }

    Search_through_all: {
        my $args = { name => 'sOcIaL', case_insensitive => 1 };
        $accounts = Socialtext::Account->All( %$args );
        is_deeply(
            [ map { $_->name } $accounts->all() ],
            ['Socialtext'],
            'Searching through All()',
        );
    }
}
