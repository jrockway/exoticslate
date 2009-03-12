#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 5;
fixtures( 'admin' );

BEGIN {
    use_ok( 'Socialtext::Attachments' );
    use_ok( 'Socialtext::Page' );
    use_ok( 'Socialtext::String' );
}

my $hub = new_hub('admin');

# test that attachments on a deleted page do not show up on
# a list of all pages

create_page('test page', 'meh');
my $all_attachments_count_before = count_all_attachments();
attach_to_page('foo.txt', 'test page');
my $all_attachments_count_middle = count_all_attachments();
delete_page('test page');
my $all_attachments_count_after = count_all_attachments();

is(
    $all_attachments_count_middle - 1, $all_attachments_count_before,
    'adding one attachment increase attachment count by one'
);
is(
    $all_attachments_count_after, $all_attachments_count_before,
    'deleting a page decreases attachment count'
);

sub create_page {
    my $title = shift;
    my $content = shift;
    Socialtext::Page->new(hub => $hub)->create(
        title => $title,
        content => $content,
        creator => $hub->current_user,
    );
}

sub attach_to_page {
    my $filename = shift;
    my $page_name = shift;

    my $filepath = 't/attachments/' . $filename;
    open my $fh, '<', $filepath or die "$filepath: $!";
    $hub->attachments->create(
        filename => $filename,
        page_id  => Socialtext::String::title_to_id($page_name),
        fh       => $fh,
        creator => $hub->current_user,
    );
}

sub count_all_attachments {
    my $attachments = $hub->attachments->all_in_workspace();
    return scalar @$attachments;
}

sub delete_page {
    my $page_name = shift;
    $hub->pages->new_from_name($page_name)->delete( user => $hub->current_user );
}
