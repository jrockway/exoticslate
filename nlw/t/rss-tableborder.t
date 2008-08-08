#!perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext;
fixtures( 'admin_no_pages' );   # we really require *NO* pages when we test
use Socialtext::Pages;

my $hub = new_hub('admin');
my @tests = (
    qr{\Q<td style="border: 1px solid black;padding: .2em;">},
    qr{\Q<table style="border-collapse: collapse;" class="formatter_table">},
);

plan tests => scalar @tests + 3;

$ENV{GATEWAY_INTERFACE} = 1;
$ENV{QUERY_STRING} = 'category=Recent%20Changes';
$ENV{REQUEST_METHOD} = 'GET';

# Verify that there are no pages in the workspace before we start
my $pages_ref = Socialtext::Model::Pages->All_active(
    workspace_id => $hub->current_workspace->workspace_id,
);
is @$pages_ref, 0, 'no pages found to start';

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
