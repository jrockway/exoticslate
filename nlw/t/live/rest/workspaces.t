#!perl
# @COPYRIGHT@
use warnings;
use strict;

use Test::HTTP::Socialtext '-syntax', 'no_plan';

use JSON::XS;
use Readonly;
use Test::Live fixtures => ['foobar'];
use Test::More;

Readonly my $WORKSPACE     => 'foobar';
Readonly my $NEW_WORKSPACE => 'party';
Readonly my $URL           => Test::HTTP::Socialtext->url("/data/workspaces");
Readonly my $TYPE          => 'application/json';

Readonly my $WS_CREATION_HASH => {
    name => $NEW_WORKSPACE,
    account_id => '1',
    logo_uri => 'http://www.burningchrome.com/~cdent/images/iocnm.png',
    title => 'A Big Party House',
};

Readonly my $WS_CREATION_JSON => encode_json($WS_CREATION_HASH);

test_http "list workspaces JSON" {
    >> GET $URL
    >> Accept: $TYPE

    << 200
    ~< Content-type: ^$TYPE(;|,|$)

    my $result = decode_json($test->response->content);

    is( ref $result, 'ARRAY', "returns a list" );

    foreach (@$result) {
        my $uri = $_->{uri};
        like(
            $uri,
            qr{^/data/workspaces/[\w-]+$},
            "'$uri' looks like a workspace URL" );
    }
}

test_http "POST workspace" {
    >> POST $URL
    >> Content-Type: $TYPE
    >>
    >> $WS_CREATION_JSON

    << 201
    ~< Location: $URL/$NEW_WORKSPACE

    >> GET $URL/$NEW_WORKSPACE
    >> Accept: $TYPE

}

test_http "POST same workspace" {
    >> POST $URL
    >> Content-Type: $TYPE
    >>
    >> $WS_CREATION_JSON

    << 409
}


test_http "Non admin user POST" {
    # Switch to non-admin user
    $Test::HTTP::BasicUsername = 'devnull2@socialtext.com';
    $Test::HTTP::BasicPassword = 'password';
    >> POST $URL
    >> Content-Type: $TYPE
    >>
    >> $WS_CREATION_JSON


    << 401
}
