#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 1;
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
        );
        $date->add( seconds => 2 );
    }
}

# get ten of them and see which ones you have
{
    my @pages = $hub->category->get_pages_for_category(
        'Recent Changes',
        10,
    );

    my @ids = map {$_->id} @pages;
    my @numbers = map {$_ =~ /_(\d+)$/; $1} @ids;

    ok(is_sequence(\@numbers), "pages returned are a sequence");
}


sub is_sequence {
    my $numbers = shift;

    my $prev;
    foreach my $number (sort {$a <=> $b} @$numbers) {
        if (defined($prev)) {
            return 0 unless ($prev + 1) == $number;
        }
        $prev = $number;
    }
    return 1;
}
