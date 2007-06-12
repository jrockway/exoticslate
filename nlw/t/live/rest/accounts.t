#!perl
# @COPYRIGHT@

use warnings;
use strict;

use Test::HTTP::Socialtext '-syntax', 'no_plan';

use JSON;
use Readonly;
use Socialtext::Account;
use Test::Live fixtures => ['admin', 'foobar'];
use Test::More;
use URI;

$JSON::UTF8 = 1;

Readonly my $BASE => Test::HTTP::Socialtext->url('/data/accounts');

my $NEW_ACCOUNT_NAME = 'account-1';
my $NEW_ACCOUNT_URL = "$BASE";

Readonly my $ACCOUNT_CREATION_HASH => {
    name => $NEW_ACCOUNT_NAME,
};

my $ACCOUNT_CREATION_JSON = objToJson($ACCOUNT_CREATION_HASH);

test_http "POST new accounts returns 201 and location" {
    >> POST $NEW_ACCOUNT_URL
    >> Content-Type: application/json
    >>
    >> $ACCOUNT_CREATION_JSON

    << 201
    ~< Location: $NEW_ACCOUNT_URL/[\d]+

    my $result = jsonToObj($test->response->content);

    is( ref $result, 'HASH', "returns a hash" );
    is( $NEW_ACCOUNT_NAME, $result->{name}, "account name was returned" );
}

# now check to see if the account got created
{
    my $account = Socialtext::Account->new( name => $NEW_ACCOUNT_NAME );
    ok( $account, "NEW_ACCOUNT was created" );
}

$Test::HTTP::BasicUsername = 'devnull2@socialtext.com';
$ACCOUNT_CREATION_JSON = objToJson( { name => 'account-2' } );

test_http "POST new accounts forbidden for non-business admin" {
    >> POST $NEW_ACCOUNT_URL
    >> Content-type: application/json
    >>
    >> $ACCOUNT_CREATION_JSON

    << 401
}

$Test::HTTP::BasicUsername = 'devnull1@socialtext.com';
$ACCOUNT_CREATION_JSON = objToJson( { no_name_is_bad => 'bad' } );
test_http "POST with bad parameters" {
    >> POST $NEW_ACCOUNT_URL
    >> Content-type: application/json
    >>
    >> $ACCOUNT_CREATION_JSON

    << 403
    <<
    ~< required field
}
