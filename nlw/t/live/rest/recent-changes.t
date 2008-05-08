#!perl
# @COPYRIGHT@

use warnings;
use strict;

use Test::HTTP::Socialtext '-syntax', 'no_plan';

use Readonly;
use Socialtext::JSON;
use Test::Live fixtures => ['admin'];
use Test::More;

Readonly my $WORKSPACE => 'admin';
Readonly my $BASE      => Test::HTTP::Socialtext->url('/data');
Readonly my $PAGES_URL => "$BASE/workspaces/$WORKSPACE/pages";
Readonly my $QUERY     => "order=newest";
Readonly my $JSON_TYPE => 'application/json';
Readonly my $HTML_TYPE => 'text/html';
Readonly my $TEXT_TYPE => 'text/plain';

# /data/workspaces/admin/pages?order=newest

my $Json_page_count = 0;

test_http "recent changes JSON" {
    >> GET $PAGES_URL?$QUERY
    >> Accept: $JSON_TYPE

    << 200
    ~< Content-type: ^$JSON_TYPE(;|,|$)
    ~< Last-Modified: ^(Sun|Mon|Tue|Wed|Thu|Fri|Sat),

    my $result = decode_json($test->response->content);

    is( ref $result, 'ARRAY', "returns a list" );

    $Json_page_count = scalar @$result;

    foreach my $page (@$result) {
        foreach my $key (
            qw( name page_uri last_editor last_edit_time
            modified_time revision_count revision_id)
            ) {
            ok( exists $page->{$key}, "$key is present" );
        }
    }
}

test_http "recent changes HTML" {
    >> GET $PAGES_URL?$QUERY
    >> Accept: $HTML_TYPE

    << 200
    ~< Content-type: ^$HTML_TYPE(;|,|$)
    ~< Last-Modified: ^(Sun|Mon|Tue|Wed|Thu|Fri|Sat),

    my @results = grep /^<li>/, split ("\n", $test->response->content);

    is( scalar @results, $Json_page_count,
        "JSON and HTML result count the same" );

    foreach my $page (@results) {
        like( $page, qr{pages/(...)\w+['"].*>\1}i,
            "page URI looks like a page URI" );
    }
}

my @All_recent_changes;
test_http "recent changes TEXT" {
    >> GET $PAGES_URL?$QUERY
    >> Accept: $TEXT_TYPE

    << 200
    ~< Content-type: ^$TEXT_TYPE(;|,|$)
    ~< Last-Modified: ^(Sun|Mon|Tue|Wed|Thu|Fri|Sat),

    @All_recent_changes = split( "\n", $test->response->content );
    is( scalar @All_recent_changes, $Json_page_count,
        "JSON and TEXT result count the same" );
}

test_http "recent changes TEXT with count" {
    >> GET $PAGES_URL?$QUERY;count=10
    >> Accept: $TEXT_TYPE

    << 200
    ~< Content-type: ^$TEXT_TYPE(;|,|$)
    ~< Last-Modified: ^(Sun|Mon|Tue|Wed|Thu|Fri|Sat),

    my @results = split( "\n", $test->response->content );
    is( scalar @results, 10,
        "TEXT result count 10 when count=10" );
}

test_http "recent changes TEXT with filter and count" {
    >> GET $PAGES_URL?$QUERY;filter=^a;count=4
    >> Accept: $TEXT_TYPE

    << 200
    ~< Content-type: ^$TEXT_TYPE(;|,|$)
    ~< Last-Modified: ^(Sun|Mon|Tue|Wed|Thu|Fri|Sat),

    my @results = split( "\n", $test->response->content );
    is( scalar @results, 3,
        "TEXT result count 3 when filter=^a" );
}

test_http "pages TEXT with order=alpha" {
    >> GET $PAGES_URL?order=alpha
    >> Accept: $TEXT_TYPE

    << 200
    
    my @results = split( "\n", $test->response->content );
    is( join('', @results), join('', sort @All_recent_changes),
        "alpha query results are sorted" );
}

