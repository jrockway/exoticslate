#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext;
fixtures( 'admin' );

my @tests = (
  [ qr{\Q<a class="saveButton" onclick="document.forms['settings'].submit(); return false" href="#">Save</a>},
    'Submit button is submit' ],
  [ qr{\Q<a class="cancelButton" onclick="document.forms['settings'].reset(); return false" href="#">Cancel</a>},
    'Cancel button is reset' ],
);

plan tests => scalar @tests;

$ENV{GATEWAY_INTERFACE} = 1;
$ENV{QUERY_STRING} = 'action=users_settings';
$ENV{REQUEST_METHOD} = 'GET';

my $hub = new_hub('admin');

my $settings = $hub->user_settings;
my $result = $settings->users_settings;
for my $test (@tests)
{
    like( $result, $test->[0], $test->[1] );
}
