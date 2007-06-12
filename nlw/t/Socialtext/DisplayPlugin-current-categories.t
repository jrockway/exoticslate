#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 3;
fixtures( 'admin' );

BEGIN {
    use_ok( 'Socialtext::DisplayPlugin' );
}

# Make sure that recent changes do not show up in the list of
# categories displayed to a user when editing a page. Yes, it's
# a private method, but this part of the world gets messed up
# often, usually through template maneuvers.

my $hub = new_hub('admin');

my $hash = $hub->category->load->all;
my @all_categories_list = map { $hash->{$_} } sort keys %$hash;
my @display_categories_list = $hub->display->_current_categories();


like( join(' ', @all_categories_list), qr{\brecent changes\b}i,
    'recent changes should be in the all categories list' );
unlike( join(' ', @display_categories_list), qr{\brecent changes\b}i,
    'recent changes should not be in the display categories list' );

