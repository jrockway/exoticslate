#!perl
# @COPYRIGHT@

use warnings;
use strict;
use utf8;

use Test::HTTP::Socialtext '-syntax', tests => 12;

use Readonly;
use Socialtext::JSON;
use Socialtext::Role;
use Socialtext::User;
use Socialtext::Workspace;

use Test::Live fixtures => ['admin', 'foobar'];
use Test::More;

Readonly my $WORKSPACES =>
    Test::HTTP::Socialtext->url('/data/workspaces');
Readonly my $PAGES =>
    Test::HTTP::Socialtext->url('/data/workspaces/admin/pages');
Readonly my $PAGE =>
    Test::HTTP::Socialtext->url('/data/workspaces/admin/pages/truculent');
Readonly my $UI =>
    Test::HTTP::Socialtext->url('/admin/index.cgi');
Readonly my $BEHALF_USER => 'devnull@urth.org';
Readonly my $OTHER_USER => 'devnull2@socialtext.com';

# devnull1 is an impersonator

my $user = Socialtext::User->new(username => $BEHALF_USER);
my $ws = Socialtext::Workspace->new(name => 'admin');
$ws->assign_role_to_user(
    user => $user,
    role => Socialtext::Role->Member,
);

test_http "GET as devnull1" {
    >> GET $PAGES
    >> Accept: text/plain

    << 200

    #diag($test->response->decoded_content)
}

test_http "GET with parameter" {
    >> GET $PAGES?on-behalf-of=$BEHALF_USER
    >> Accept: text/plain

    << 200

    #diag($test->response->decoded_content)
}

test_http "GET with header" {
    >> GET $PAGES
    >> X-On-Behalf-Of: $BEHALF_USER
    >> Accept: text/plain

    << 200

    #diag($test->response->decoded_content)
}

test_http "GET the UI" {
    >> GET $UI?on-behalf-of=$BEHALF_USER

    << 200
}

test_http "GET workspaces with behalf" {
    >> GET $WORKSPACES?on-behalf-of=$BEHALF_USER

    << 403

    diag($test->response->decoded_content)
}

test_http "GET workspaces without behalf" {
    >> GET $WORKSPACES

    << 200
}

test_http "GET with header and param" {
    >> GET $PAGES?on-behalf-of=$BEHALF_USER
    >> X-On-Behalf-Of: $OTHER_USER

    << 200
}

test_http "PUT a page" {
    >> PUT $PAGE
    >> X-On-Behalf-Of: $BEHALF_USER
    >> Content-Type: text/x.socialtext-wiki
    >>
    >> Howdy Ho

    << 201
}

test_http "GET page back" {
    >> GET $PAGE
    >> Accept: application/json

    << 200

    my $info = decode_json($test->response->decoded_content());
    is $info->{last_editor}, $BEHALF_USER, 'on behalf user is author'
}

# devnull1 is no longer an impersonator
my $user = Socialtext::User->new(username => 'devnull1@socialtext.com');
my $ws = Socialtext::Workspace->new(name => 'admin');
$ws->assign_role_to_user(
    user => $user,
    role => Socialtext::Role->Member,
);

test_http "GET with header, behalf fail" {
    >> GET $PAGES
    >> X-On-Behalf-Of: $BEHALF_USER
    >> Accept: text/plain

    << 403

    #diag($test->response->decoded_content)
}

test_http "GET the UI, behalf fail" {
    >> GET $UI?on-behalf-of=$BEHALF_USER

    << 403
}

