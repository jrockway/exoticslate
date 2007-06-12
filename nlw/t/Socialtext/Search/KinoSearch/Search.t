#!/usr/bin/env perl
# -*- coding: utf-8 -*- vim:fileencoding=utf-8:
# @COPYRIGHT@
use strict;
use warnings;

use utf8;
use Test::Socialtext tests => 191;
fixtures( 'admin_no_pages' );

BEGIN { use_ok("Socialtext::Search::KinoSearch::Factory") }

our $workspace = 'admin';
our $hub = new_hub('admin');

BASIC_SEARCH: {
    erase_index_ok();
    make_page_ok(
        "Cows Rock",
        "There is no such thing as a chicken that dances"
    );
    search_ok( "dances",        1, "Simple word search (in body)" );
    search_ok( "Cows",          1, "Simple word search (in title)" );
    search_ok( "title:Cows",    1, "Title search" );
    search_ok( "=Cows",         1, "Title (=) search" );
    search_ok( "It is raining", 0, "Nonsense" );
}

MORE_FEATURED_SEARCH: {
    erase_index_ok();
    make_page_ok( "Tom Stoppard", <<'QUOTE', [ "man likes dog", "man" ] );
We cross our bridges when we come to them and burn them behind us, with
nothing to show for our progress except a memory of the smell of smoke, and a
presumption that once our eyes watered.
QUOTE
    search_ok( "bridges",  1, "Literal word search" );
    search_ok( "bridge",   1, "Depluralized word search" );
    search_ok( "bridging", 1, "Similarly stemmed word search" );
    search_ok(
        "The smoking bridge smells", 1,
        "Multiple Word Search with Stemming"
    );
    search_ok(
        "bridge idonotexist", 0,
        "Assert searching defaults to AND connectivity"
    );
    search_ok( '"smell of smoke"', 1, "Phrase search" );
    search_ok( 'bridges -smoke',   0, "Search with negation" );
    search_ok(
        'bridges AND NOT "smell of smoke"', 0,
        "Search with phrase negation"
    );
    search_ok(
        'bridges AND NOT "smoke on the water"', 1,
        "Search without Deep Purple "
    );
    search_ok( "tag:man", 1, "Tag search with word which is standalone" );
    search_ok( "tag:dog", 1, "Tag search with word not also standalone" );
    search_ok( "tag:\"man likes dog\"", 1, "Tag search with phrase" );
    search_ok( "tag:idonotexst", 0, "Tag search for a non-existant tag" );
}

FLEXING_MULTIPLE_PAGES: {
    erase_index_ok();
    make_page_ok( "Tom Stoppard", <<'QUOTE', [ "quotes", "writers" ] );
We cross our bridges when we come to them and burn them behind us, with
nothing to show for our progress except a memory of the smell of smoke, and a
presumption that once our eyes watered.
QUOTE
    make_page_ok( "Neil Gaiman", <<'QUOTE', [ "quotes", "writers" ] );
It has always been the prerogative of children and half-wits to point out that
the emperor has no clothes. But the half-wit remains a half-wit, and the
emperor remains an emperor.
QUOTE
    make_page_ok( "Louis Jenkins", <<'QUOTE', [ "poems", "writers" ] );
Diner
 
The time has come to say goodbye, our plates empty except for our greasy
napkins. Comrades, you on my left, balding, middle-aged guy with a ponytail,
and you, Lefty there on my right, though we barely spoke I feel our kinship.
You were steadfast in passing the ketchup, the salt and pepper, no man could
ask for better companions. Lunch is over, the cheeseburgers and fries, the
Denver sandwich, the counter nearly empty. Now we must go our separate ways.
Not a fond embrace, but perhaps a hearty handshake. No? Well then, farewell.
It is unlikely I'll pass this way again. Unlikely we will ever meet again on
this earth, to sit together beneath the neon and fluorescent calmly sipping
our coffee, like the sages sipping their tea underneath the willow, sitting
quietly, saying nothing.
QUOTE
    search_ok( "bridges OR children", 2, "Disjunctive Search" );
    search_ok( "the",                 3, "Common word" );

    search_ok( "tag:writers",       3, "Common tags" );
    search_ok( "tag: writers",      3, "Field search with a space" );
    search_ok( "tag:      writers", 3, "Field search with lots of spaces" );
    search_ok(
        "tag:writers AND tag:quotes", 2,
        "Common tags, with conjunction"
    );

    search_ok( "category:writers", 3, "Common categories (alias for tags)" );
    search_ok(
        "category:writers AND category:poems", 1,
        "Common categories (alias for tags), with conjunction"
    );

    search_ok( "(sages OR bridges) AND (tea OR emperor)", 1,
        "More complex search" );
}

RT22174_TITLE_SEARCH_BUG: {
    erase_index_ok();
    make_page_ok( "Beamish Stout", 'has thou slain the jabberwock' );
    make_page_ok( "light", 'is beamish.  has thou slain the jabberwock' );
    search_ok( '"has thou slain the jabberwock" AND title:beamish', 1, "" );
    search_ok( '"has thou slain the jabberwock" AND =beamish',      1, "" );
    search_ok( '=beamish AND "has thou slain the jabberwock"',      1, "" );
}

BASIC_UTF8: {
    erase_index_ok();
    my $utf8 = "big and Groß";
    make_page_ok( $utf8, "Cows are good but $utf8 en français",
        ["español"] );
    search_ok( "français",         1, "Utf8 body search" );
    search_ok( "Groß",             1, "Utf8 general search" );
    search_ok( "Groß français",   1, "Utf8 search with implicit AND" );
    search_ok( "title:Groß",       1, "Utf8 title search" );
    search_ok( "=Groß",            1, "Utf8 title search (=)" );
    search_ok( "tag:español",      1, "Utf8 tag search" );
    search_ok( "category:español", 1, "Utf8 tag search" );
    search_ok(
        "Groß AND (français OR tag:español) AND category:español",
        1, "Complicated search with UTF-8"
    );

    # Ensure the tokenizer/stemmers aren't just ignoring the UTF-8
    search_ok( "Gro",          0, "UTF-8 not lost in stemming" );
    search_ok( "Gro ",         0, "UTF-8 not lost in stemming" );
    search_ok( "franais",      0, "UTF-8 not substititued away" );
    search_ok( "fran ais",     0, "UTF-8 not substititued away" );
    search_ok( "fran",         0, "UTF-8 not used as token seperator" );
    search_ok( "tag:espa",     0, "UTF-8 not used as token seperator" );
    search_ok( "tag:espa nol", 0, "UTF-8 not used as token seperator" );
}

LOTS_OF_HITS: {
    erase_index_ok();
    for my $n ( 1 .. 105 ) {
        make_page_ok( "Page Test $n", "The contents are $n" );
    }
    search_ok( "Page Test", 105, "Big result sets returned ok" );
}

INDEX_AND_SEARCH_A_BIG_DOCUMENT: {
    my $text = "Mary had a little lamb and it liked to drink. " x 100000;
    erase_index_ok();
    ok( 1, '(Indexing big document (4.4 MB), to suss out $& bugs)' );
    make_page_ok( "Really Big Page", $text );
    search_ok( "lamb", 1, "Searching for the big page" );
}

BASIC_WILDCARD_SEARCH: {
    erase_index_ok();
    my @words = split /\s+/, "When the roofers are done roofing the roof.";
    my $n = 0;
    for my $word (@words) {
        $n++;
        make_page_ok( "Wildcard $n: $word", $word, ["cow_$word"] );
    }
    search_ok( "roof*",          3, "Searching for roof*" );
    search_ok( "ro*",            0, "No wildcard when term too short" );
    search_ok( "title:wildcard", 8, "Searching for wildcard" );
    search_ok( "title: wild*",   8, "Searching for title: wild*" );
    search_ok( "title:wild*",    8, "Searching for title:wild*" );
    search_ok( "=wild*",         8, "Searching for title:wild*" );
    search_ok( "whe* OR don*",   2, "Searching for wildcard in disjunction" );
    search_ok( "whe* -don*",     1, "Searching with negation of wildcard" );
    search_ok( "category:cow_roof*", 3, "Searching for wildcard in category" );
    search_ok( "tag:cow_roof*", 3, "Searching for wildcard in tag" );
    search_ok( "tag:cow_roof*", 3, "Searching for wildcard in tag w/ caps." );
    search_ok( "(roof*)", 3, "Searching for wildcard in tag in parens." );
}

sub make_page_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ( $title, $content, $tags ) = @_;
    my $page = $hub->pages->new_from_name($title);
    $page->update(
        user             => $hub->current_user,
        subject          => $title,
        content          => $content,
        categories       => $tags || [],
        original_page_id => $page->id,
        revision         => $page->metadata->Revision || 0,
    );
    index_ok( $page->id );

    return $page;
}

sub search_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ( $term, $num_of_results, $text ) = @_;
    my @results = eval { searcher()->search($term) };
    diag($@) if $@;

    my $hits = ( $num_of_results == 1 ) ? "hit" : "hits";
    is(
        scalar @results,
        $num_of_results,
        "'$term' returns $num_of_results $hits: $text"
    );

    return @results;
}

sub index_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $INDEX_MAX = 60;    # 60 seconds to index a page.

    my $page = shift;
    my $id   = ref($page) ? $page->id : $page;

    # Use a double eval in case the alarm() goes off in between returing from
    # the inner eval and before alarm(0) is executed.
    my $fail;
    eval {
        local $SIG{ALRM} = sub {
            die "Indexing $id is taking more than $INDEX_MAX seconds.\n";
        };
        alarm($INDEX_MAX);
        eval { 
            indexer()->index_page($id);
        };
        $fail = $@;
        alarm(0);
    };

    diag("ERROR Indexing $id: $fail\n") if $fail;
    ok( not($fail), "Indexing $id" );
}

sub erase_index_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    eval { indexer()->delete_workspace($workspace) };
    diag("erase_index_ok: $@\n") if $@;
    ok( not($@), "============ ERASED INDEX =============" );
}

sub searcher {
    Socialtext::Search::KinoSearch::Factory->create_searcher($workspace);
}

sub indexer {
    Socialtext::Search::KinoSearch::Factory->create_indexer($workspace);
}
