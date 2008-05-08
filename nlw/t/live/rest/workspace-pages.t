#!perl
# @COPYRIGHT@

use warnings;
use strict;

# see also rest-recent-changes.t

use Test::Live fixtures => ['admin'];

use Readonly;
use Socialtext::JSON;
use Test::Socialtext::Environment;
use Test::HTTP::Syntax;
use Test::HTTP 'no_plan';
use Test::More;
use t::SocialtextTestUtils qw/index_page/;

$Test::HTTP::BasicUsername = 'devnull1@socialtext.com';
$Test::HTTP::BasicPassword = 'd3vnu11l';

Readonly my $LIVE          => Test::Live->new();
Readonly my $BASE          => $LIVE->base_url . '/data/workspaces/admin/pages';

Readonly my $NEW_BODY      => "Floss. Do not forget to floss.\n";

my $page_uri;
my $all_pages_content;

test_http "DELETE pages is a bad method" {
    >> DELETE $BASE

    << 405
    ~< Allow: ^GET, HEAD, POST
}

test_http "POST results in new page" {
    >> POST $BASE
    >> Content-Type: text/x.socialtext-wiki
    >>
    >> $NEW_BODY

    << 201
    ~< Location: http://[^/]+/data/workspaces/admin/pages/devnull1

    $page_uri = $test->response->header('location');
}


test_http "POST with bad content errors" {
    >> POST $BASE
    >> Content-Type: text/html
    >>
    >> <html><body>$NEW_BODY</body></html>

    # is it 415 or 406 here
    << 415

}

test_http "GET page has correct content" {
    >> GET $page_uri
    >> Accept: text/x.socialtext-wiki

    << 200

    my $content = $test->response->content();

    is( $content, $NEW_BODY, "page content is what was sent" );
}

test_http "DELETE a page, it goes away" {
    >> DELETE $BASE/admin_wiki

    << 204

    >> GET $BASE
    >> Accept: application/json

    << 200

    my $content = eval { decode_json($test->response->content) };
    is( $@, '', 'JSON is well formed.' );

    for (@$content) {
        if ($_->{page_id} eq 'admin_wiki') {
            fail('deleted page is removed from collection.');
            goto DONE;
        }
    }
    pass('deleted page is removed from collection.');

    DONE:
}

test_http "GET pages list" {
    >> GET $BASE
    >> Accept: application/json

    << 200

    my $content = eval { decode_json($test->response->content) };
    is( $@, '', 'JSON is well formed.' );
    # Setting global for use in next test.  Ugly.
    $all_pages_content = $content;

    my @keys = qw( page_uri page_id name modified_time uri revision_id 
        last_edit_time last_editor revision_count workspace_name type tags);
    for my $page (@$content) {
        is( keys %$page, scalar(@keys), "Page has correct number of keys." );
        ok( exists $page->{$_}, "Page contains $_." ) for @keys;
        isa_ok( $page->{tags}, 'ARRAY', "Page tags" );

        is_deeply( $page->{tags}, ['Welcome', 'Recent Changes'], "Quick Start has proper tags" )
            if $page->{name} eq 'Quick Start';
    }
}

test_http "GET pages search" {
    >> GET $BASE?q=link
    >> Accept: application/json

    << 200

    my $content = eval { decode_json($test->response->content) };
    is( $@, '', 'JSON is well formed.' );
    ok( @$content < @$all_pages_content, "Fewer pages in search result than workspace overall." )
}

#############
# Test REST Search
# Clear the ceqlotron, then index the 2 files we're searching for
# This is much faster than indexing everything
#

use Socialtext::Ceqlotron;
warn "# Cleaning the Ceqlotron queue\n";
Socialtext::Ceqlotron::clean_queue_directory();

$ENV{NLW_APPCONFIG} = 'ceqlotron_synchronous=1';
warn "# Indexing pages for IWS Rest test\n";
index_page('help-en', 'what_s_the_funny_punctuation');
index_page('admin', 'what_s_the_funny_punctuation');
#############

test_http "GET interworkspace search" {
    >> GET $BASE?q=title:funny+workspaces:help-en,admin
    >> Accept: application/json

    << 200

    my $content = eval { decode_json($test->response->content) };
    is( $@, '', 'JSON is well formed.' );

    my %workspaces_seen;
    for my $page (@$content) {
        ok( exists $page->{workspace_name}, "Result has workspace_name attribute." );
        $workspaces_seen{ $page->{workspace_name} }++;
    }

    is_deeply( [ keys %workspaces_seen ], [ sort qw( admin help-en ) ], "Result set has appropriate workspaces" );
}

test_http "GET interworkspace search links via HTML" {
    >> GET $BASE?q=title:funny+workspaces:help-en
    >> Accept: text/html

    << 200

    my $body = $test->response->decoded_content();
    like $body,
        qr{<a href=.\.\./help-en/pages/what_s_the_funny.*?>},
        'Interwiki results are linked relative to the current workspace';
}

exit;
