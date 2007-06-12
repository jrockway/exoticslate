#!perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::More tests => 3;

{
    $INC{'Socialtext/AppConfig.pm'} = 1;
    package Socialtext::AppConfig;

    sub db_connect_params {
        ( db_schema_name => 'NLW',
          user => 'foo',
          password => 'bar',
        )
    }
}

use Alzabo::Driver::PostgreSQL;
require Socialtext::Schema;

no warnings 'redefine';
local *Alzabo::Driver::PostgreSQL::connect = sub { 1 };

my $schema = Socialtext::Schema->LoadAndConnect();

isa_ok( $schema, 'Alzabo::Runtime::Schema',
        'LoadAndConnect() returns an Alzabo::Runtime::Schema object' );
is( $schema->user, 'foo', 'db user in schema is foo' );
is( $schema->password, 'bar', 'db password in schema is bar' );
