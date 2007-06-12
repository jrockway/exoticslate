#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext;
fixtures( 'admin_no_pages' );
use Socialtext::Pages;

my $hub = new_hub('admin');
my @tests = (
    qr{\Q<td style="border: 1px solid black;padding: .2em;">},
    qr{\Q<table style="border-collapse: collapse;" class="formatter_table">},
);

plan tests => scalar @tests + 2;

$ENV{GATEWAY_INTERFACE} = 1;
$ENV{QUERY_STRING} = 'category=Recent%20Changes';
$ENV{REQUEST_METHOD} = 'GET';

Socialtext::Page->new(hub => $hub)->create(
    title => 'a table page',
    content => <<"EOF",

^^^ Hello Friends

|This table| is for|
|you |and you only|

EOF
    creator => $hub->current_user,
);

my $syndicate = $hub->syndicate;
isa_ok( $syndicate, 'Socialtext::SyndicatePlugin' );

my $result = $syndicate->syndicate->as_xml;
ok( $result, '->syndicate returns a non-empty string' );

for my $test (@tests) {
    like $result, $test;
}
