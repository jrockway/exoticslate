#!perl
# @COPYRIGHT@

use strict;
use warnings;
BEGIN { $ENV{NLW_LIVE_DANGEROUSLY} = 1 }
use Test::Socialtext tests => 7;
# This test suite *needs* to have no pages in the admin workspace when its
# run.
fixtures('admin_no_pages');

BEGIN {
    use_ok( "Socialtext::Page" );
}

my $hub = new_hub('admin');

my $page1 = create_page_with_tags( 'one',   'tag1', 'tag2' );
my $page2 = create_page_with_tags( 'two',   'tag1', 'tag3' );
create_page_with_tags( 'three', 'tag1', 'tag4' );

WEIGHTED_CATEGORIES_FOR_PAGE: {
    my %tags = $hub->category->weight_categories(
        @{ $page1->metadata->Category } );

    is $tags{maxCount}, 3, 'the maxCount should be 3';
    is $tags{tags}->[0]->{page_count}, 3, 'the count of tag tag1 should be 3';
    is $tags{tags}->[1]->{page_count}, 1, 'the count of some other tag should be 1';

    # REVIEW: asymetry between add_tags and delete_tag, former does its own
    # store
    $page2->delete_tag('tag1');
    $page2->metadata->update(user => $hub->current_user);
    $page2->store( user => $hub->current_user );
    %tags = $hub->category->weight_categories(
        @{ $page1->metadata->Category } );
    is $tags{tags}->[0]->{page_count}, 2,
        'the count of tag tag1 should be 2 after delete_tags';
}

WEIGHTED_CATEGORIES_FOR_WORKSPACE: {
    my %tags = $hub->category->weight_categories();

    is $tags{maxCount}, 2, 'the maxCount should be 2';
    is $tags{tags}->[0]->{page_count}, 2,
        'the count of tag tag1 should be 2 for the workspace';
}

sub create_page_with_tags {
    my $title = shift;
    my @tags  = @_;

    my $page = Socialtext::Page->new(hub => $hub)->create(
        title => $title,
        content => 'It does not matter',
        creator => $hub->current_user,
    );

    # calls store
    $page->add_tags(@tags);

    return $page;
}
