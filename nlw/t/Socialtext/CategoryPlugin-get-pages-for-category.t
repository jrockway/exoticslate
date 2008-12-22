#!perl
# @COPYRIGHT@

use strict;
use warnings;

BEGIN { $ENV{NLW_LIVE_DANGEROUSLY} = 1 }

use Test::Socialtext tests => 4;
fixtures( 'admin' );
use Socialtext::Pages;
use DateTime;

my $hub = new_hub('admin');

# create pages
{
    my $date = DateTime->now->add( seconds => 60 );
    for my $i (1 .. 20) {
        Socialtext::Page->new(hub => $hub)->create(
            title => "page title $i",
            content => "page content $i",
            date => $date,
            creator => $hub->current_user,
            categories => ['rad', ($i % 2 ? 'odd' : 'even')],
        );
        $date->add( seconds => 2 );
    }
}

# get ten of them and see which ones you have
Get_with_limit: {
    my @pages = $hub->category->get_pages_for_category( 'rad', 10 );
    my @ids = map {$_->id} @pages;
    my @numbers = map {$_ =~ /_(\d+)$/; $1} @ids;

    is join(',', @numbers), join(',', reverse 11 .. 20), 'pages returned in sequence';
    is scalar(@numbers), 10, 'got 10 pages';
}

Get: {
    my @pages = $hub->category->get_pages_for_category( 'even' );
    my @ids = map {$_->id} @pages;
    my @numbers = map {$_ =~ /_(\d+)$/; $1} @ids;

    is join(',', @numbers), join(',', grep { !($_ % 2) } reverse 1 .. 20),
        'pages returned in sequence';
    is scalar(@numbers), 10, 'got 10 pages';
}


