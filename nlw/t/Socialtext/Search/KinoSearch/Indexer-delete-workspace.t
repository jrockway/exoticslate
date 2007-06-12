#!perl
# @COPYRIGHT@
use strict;
use warnings;

BEGIN {
    $ENV{NLW_APPCONFIG} = 'search_factory_class=Socialtext::Search::KinoSearch::Factory';
}

use Test::Socialtext;
fixtures( 'admin_no_pages' );
use Test::Socialtext::Search;

plan tests => 19;

my $hub            = Test::Socialtext::Search::hub();
my $workspace_name = $hub->current_workspace->name;
my $index_dir = Socialtext::Paths::plugin_directory($workspace_name) . '/kinosearch';
my $segments_file = $index_dir . '/segments';

# make an index and confirm it's workiness
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
