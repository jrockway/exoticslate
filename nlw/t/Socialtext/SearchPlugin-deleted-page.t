#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 9;
fixtures( 'admin' );

use Test::Socialtext::Search;

my $hub = Test::Socialtext::Search::hub();

{
    my $title = 'A Page with a Wacktastic Title';
    create_and_confirm_page(
        $title,
        'totally irrelevant'
    );
    search_for_term('wacktastic');

    delete_page($title);

    search_for_term( 'wacktastic', 'should not be found' );
}
