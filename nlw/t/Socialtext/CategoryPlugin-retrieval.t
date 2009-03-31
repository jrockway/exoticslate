#!perl
# @COPYRIGHT@

use strict;
use warnings;
use DateTime;
use Socialtext::Pages;
use Test::Socialtext tests => 7;

###############################################################################
# Fixtures: db
# - need a DB but don't care what's in it
fixtures(qw( db ));

# Create a dummy/test Hub
my $hub  = create_test_hub();
my $user = $hub->current_user;

# Create a bunch of pages
my $date = DateTime->now()->add( seconds => 60 );
for my $i (0 .. 9) {
    Socialtext::Page->new(hub => $hub)->create(
        title   => "page $i",
        content => "page $i",
        date    => $date,
        creator => $user,
    );
    $date->add( seconds => 5 );
}

my $category = $hub->category;
my @pages = $category->get_pages_numeric_range(
    'recent changes', 2, 9
);

my $count = 7;
for my $page (@pages) {
    is($page->title, "page $count", "title, page $count, is correct");
    $count--;
}

