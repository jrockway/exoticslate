#!perl
# @COPYRIGHT@

use warnings;
use strict;

use Test::HTTP::Socialtext '-syntax', tests => 17;

use Readonly;
use Socialtext::JSON;
use Socialtext::User;
use Test::Live fixtures => ['admin', 'foobar'];
use Test::More;

Readonly my $BASE => Test::HTTP::Socialtext->url('/data/workspaces');
Readonly my $WORKSPACE_NAME     => 'admin';
Readonly my $BAD_WORKSPACE_NAME => 'partay';
Readonly my $WORKSPACE_TITLE    => 'Admin Wiki';
Readonly my $PEON               => 'devnull2@socialtext.com';

test_http "GET existing workspace as html" {
    >> GET $BASE/$WORKSPACE_NAME
    >> Accept: text/html

    << 200
    ~< Content-Type: text/html
    <<
    ~< <a href='[^']+\Q$WORKSPACE_NAME\E/pages'>

}

test_http "GET non-existing workspace" {
    >> GET $BASE/$BAD_WORKSPACE_NAME
    >> Accept: text/html

    << 404

}

test_http "GET existing workspace as json by admin" {
    >> GET $BASE/$WORKSPACE_NAME
    >> Accept: application/json

    << 200
    ~< Content-Type: application/json

    my $object = decode_json($test->response->content());

    ok scalar keys(%$object) > 4,
        'admin request gets lots of info for workspace';
}

$Test::HTTP::BasicUsername = $PEON;
test_http "GET existing workspace as json by non-member" {
    >> GET $BASE/$WORKSPACE_NAME
    >> Accept: application/json

    << 403
}

# Make devnull2 a member of admin
my $user = Socialtext::User->new( username => $PEON );
Socialtext::Workspace->new(name => 'admin')->add_user(user => $user);
test_http "GET existing workspace as json by peon" {
    >> GET $BASE/$WORKSPACE_NAME
    >> Accept: application/json

    << 200
    ~< Content-Type: application/json

    my $object = decode_json($test->response->content());

    ok scalar keys(%$object) < 5,
        'peon gets less info for workspace';

    is $object->{title}, 'Admin Wiki', 'the title is Admin Wiki';
}

test_http "HEAD non-existant workspace" {
    >> HEAD $BASE/$BAD_WORKSPACE_NAME
    >> Accept: text/html

    << 404
}

Readonly my $SHORT_WORKSPACE_NAME => "aa";
test_http "GET short workspace name" {
    >> GET $BASE/$SHORT_WORKSPACE_NAME
    >> Accept: text/html

    << 400
}

test_http "GET short workspace name return 400 with error content" {
    >> GET $BASE/$SHORT_WORKSPACE_NAME
    >> Accept: application/json

    << 400
    ~< Content-Type: text/plain

    like( $test->response->content(), qr/3 and 30/,
        'error message was returned for "aa"' );
}

