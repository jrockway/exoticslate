#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 4;
fixtures( 'admin' );

use Socialtext::Ceqlotron;
use Socialtext::Search::AbstractFactory;

Socialtext::Ceqlotron::clean_queue_directory();

my $hub = new_hub('admin');
Socialtext::Search::AbstractFactory->GetFactory->create_indexer('admin')
    ->index_page('quick_start');
ceqlotron_run_synchronously();

{
    $hub->search->search_for_term('the');

    my $set = $hub->search->result_set;
    ok( $set, 'we have results' );
    ok( $set->{hits} > 0, 'result set found hits' );
    like( $set->{rows}->[0]->{Date}, qr/\d+/, 'date has some numbers in it');
    like( $set->{rows}->[0]->{DateLocal}, qr/\d+/,
        'date local has some numbers in it');
}
