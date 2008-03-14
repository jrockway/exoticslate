#!perl
# @COPYRIGHT@

use strict;
use warnings;

# Stick this in a begin block, so that we create the fixture right away
# Then, when we load Test::Socialtext::Search, it will clear the ceq queue
BEGIN {
    use Test::Socialtext tests => 9;
    fixtures( 'admin' );
}
use Test::Socialtext::Search;
use Socialtext::Ceqlotron;
use Socialtext::Search::AbstractFactory;

my $hub = Test::Socialtext::Search::hub();

Socialtext::Search::AbstractFactory->GetFactory->create_indexer('admin')
    ->index_page('quick_start');

# fast
do_searches();

# search for number (plucene simple no index numbers)
search_for_term('1', 'negate');
exit;


sub do_searches {
    # test for a simple entry
    search_for_term('the');
    # test the "AND"ing of terms
    search_for_term('the impossiblesearchterm', 'negate');
}
