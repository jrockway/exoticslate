#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 21;
fixtures( 'admin' );
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

# switch to slow search
$ENV{NLW_APPCONFIG} = 'search_factory_class=Socialtext::Search::Basic::Factory';
do_searches();
search_for_term('1');

sub do_searches {
    # test for a simple entry
    search_for_term('the');
    # test the "AND"ing of terms
    search_for_term('the impossiblesearchterm', 'negate');
}
