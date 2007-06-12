#!perl
# @COPYRIGHT@

use warnings;
use strict;

# see also rest-recent-changes.t

use Test::Live fixtures => ['admin'];

use Readonly;
use Test::Socialtext::Environment;
use Test::HTTP::Syntax;
use Test::HTTP 'no_plan';
use Test::More;
use JSON;

$JSON::UTF8 = 1;

$Test::HTTP::BasicUsername = 'devnull1@socialtext.com';
$Test::HTTP::BasicPassword = 'd3vnu11l';

Readonly my $LIVE          => Test::Live->new();
Readonly my $BASE          => $LIVE->base_url . '/data/workspaces/admin/pages';

Readonly my $NEW_BODY      => "Floss. Do not forget to floss.\n";

my $page_uri;

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

    my $content = eval { jsonToObj($test->response->content) };
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

    my $content = eval { jsonToObj($test->response->content) };
    is( $@, '', 'JSON is well formed.' );

    for my $page (@$content) {
        is( keys %$page, 10, "Page has 10 keys." );
        ok( exists $page->{$_}, "Page contains $_." ) for qw(
            page_uri page_id name modified_time uri revision_id last_edit_time
            last_editor revision_count);
        isa_ok( $page->{tags}, 'ARRAY', "Page tags" );

        is_deeply( $page->{tags}, ['Welcome'], "Quick Start has proper tags" )
            if $page->{name} eq 'Quick Start';
    }
}
