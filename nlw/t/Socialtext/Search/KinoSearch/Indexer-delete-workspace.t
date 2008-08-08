#!perl
# @COPYRIGHT@
use strict;
use warnings;

BEGIN {
    $ENV{NLW_APPCONFIG} = 'search_factory_class=Socialtext::Search::KinoSearch::Factory';
}

use Test::Socialtext;
fixtures( 'admin' );
use Test::Socialtext::Search;
use Socialtext::Search::Config;

plan tests => 19;

my $hub            = Test::Socialtext::Search::hub();
my $workspace_name = $hub->current_workspace->name;
my $config = Socialtext::Search::Config->new;
my $segments_file
    = $config->index_directory( workspace => $workspace_name )
    . '/segments';

# make an index and confirm it works
index_exists();

# remove the index
index_removed();

# makes sure things still work when we try again
index_exists();

sub index_exists {
    create_and_confirm_page(
        'a test page',
        "a simple page containing a funkity string"
    );
    search_for_term('funkity');

    ok( -f $segments_file, 'kinosearch segments file exists' );
}

sub index_removed {
    Socialtext::Search::KinoSearch::Factory->create_indexer(
        $hub->current_workspace->name )->delete_workspace();

    ok( !-f $segments_file, 'kinosearch segments file is gone' );

    search_for_term('funkity', 1);

}
