#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext;
fixtures( 'admin_no_pages' );

my @tests = (
  [ qr{\Q<input type="submit" name="Button" value="Save"},
    'Submit button is submit' ],
  [ qr{\Q<input type="reset" name="Button" value="Cancel"},
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
