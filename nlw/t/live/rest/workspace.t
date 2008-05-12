#!perl
# @COPYRIGHT@

use warnings;
use strict;

use Test::HTTP::Socialtext '-syntax', tests => 26;

use Readonly;
use Socialtext::JSON;
use Socialtext::User;
use Test::Live fixtures => ['admin', 'foobar', 'auth-to-edit', 'public'];
use Test::More;

Readonly my $BASE => Test::HTTP::Socialtext->url('/data/workspaces');
Readonly my $WORKSPACE_NAME     => 'admin';
Readonly my $BAD_WORKSPACE_NAME => 'partay';
Readonly my $WORKSPACE_TITLE    => 'Admin Wiki';
Readonly my $PEON               => 'devnull2@socialtext.com';
Readonly my $ADMIN              => 'devnull1@socialtext.com';

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

$Test::HTTP::BasicUsername = $PEON;
test_http "DELETE workspace by peon 403s" {
    >> DELETE $BASE/$WORKSPACE_NAME

    << 403
}

test_http "DELETE non-existent workspace gets 403 when peon" {
    >> DELETE $BASE/$BAD_WORKSPACE_NAME

    << 403
}

$Test::HTTP::BasicUsername = $ADMIN;
test_http "DELETE non-existent workspace gets 404 when not peon" {
    >> DELETE $BASE/$BAD_WORKSPACE_NAME

    << 404
}

# confirm the workspace is really gone
my $workspace = Socialtext::Workspace->new(name => $WORKSPACE_NAME);
ok $workspace, 'workspace named ' . $WORKSPACE_NAME . ' found';

# make the peon a workspace admin (but not business or technical)
my $role = Socialtext::Role->new( name => 'workspace_admin' );
Socialtext::Workspace->new(name => 'admin')->add_user(user => $user, role => $role);
test_http "DELETE workspace by workspace admin gets 204" {
    >> DELETE $BASE/$WORKSPACE_NAME

    << 204
}

# confirm the workspace is really gone
$workspace = Socialtext::Workspace->new(name => $WORKSPACE_NAME);
is $workspace, undef, 'no workspace named ' . $WORKSPACE_NAME;

# remove workspace_admin, but keep business admin
$user = Socialtext::User->new(username => $ADMIN);
Socialtext::Workspace->new(name => 'foobar')->remove_user(user => $user);
$user->set_technical_admin(0);
test_http "DELETE workspace by business admin is 204" {
    >> DELETE $BASE/foobar

    << 204
}

$user->set_technical_admin(1);
$user->set_business_admin(0);
test_http "DELETE workspace by technical admin is 204" {
    >> DELETE $BASE/auth-to-edit

    << 204
}

$user->set_technical_admin(0);
$user->set_business_admin(0);
test_http "DELETE workspace by non-admin is 403" {
    >> DELETE $BASE/public

    << 403
}

