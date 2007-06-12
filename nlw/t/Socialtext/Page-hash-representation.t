#!perl
# @COPYRIGHT@

use warnings;
use strict;

use Test::Socialtext tests => 11;
fixtures('admin_no_pages');

BEGIN {
    use_ok( 'Socialtext::Page' );
}

my $hub       = new_hub('admin');
my $page_name = 'update page';
my $content1  = 'one content';

{
    my $page = Socialtext::Page->new( hub => $hub )->create(
        title   => $page_name,
        content => $content1,
        creator => $hub->current_user,
    );
}

{
    my $page = $hub->pages->new_from_name($page_name);
    my $hash = $page->hash_representation();

    is $hash->{name},    'update page', 'hash name element is update page';
    is $hash->{uri},     'update_page', 'hash uri element is update_page';
    is $hash->{page_id}, 'update_page', 'hash page_id element is update_page';
    is $hash->{revision_count}, 1, 'revision count is 1';
    is $hash->{last_editor}, 'devnull1@socialtext.com',
        'hash last_editor is devnull1';


    like $hash->{last_edit_time}, qr{^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d GMT$},
        'last_edit_time looks like a date';
    like $hash->{modified_time}, qr{^\d+$},
        'modified time looks like an epoch time';
    like $hash->{revision_id}, qr{^\d{14}$},
        'revision_id is correctly formatted';
    like $hash->{page_uri}, qr{/admin/index.cgi\?update_page},
        'page_uri contains index.cgi';

    # update the page
    # first the obligatory sleep because our revisions ids are lame
    sleep 1;
    $page->content('something new');
    $page->store(user => $hub->current_user);
}

{
    my $page = $hub->pages->new_from_name($page_name);
    my $hash = $page->hash_representation();

    is $hash->{revision_count}, 2, 'after edit revision count is 2';
}
