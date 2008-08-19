#!perl
# @COPYRIGHT@

use warnings;
use strict;

use Test::Socialtext tests => 11;
fixtures('admin');

BEGIN {
    use_ok( 'Socialtext::Page' );
}

my $hub       = new_hub('admin');
my $page_name = 'update page ' . time();
my $content1  = 'one content';
my $page_id   = Socialtext::Page->name_to_id($page_name);

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

    is $hash->{name},    $page_name, "hash name element is $page_name";
    is $hash->{uri},     $page_id,   "hash uri element is $page_id";
    is $hash->{page_id}, $page_id,   "hash page_id element is $page_id";
    is $hash->{revision_count}, 1, 'revision count is 1';
    is $hash->{last_editor}, 'devnull1@socialtext.com',
        'hash last_editor is devnull1';


    like $hash->{last_edit_time}, qr{^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d GMT$},
        'last_edit_time looks like a date';
    like $hash->{modified_time}, qr{^\d+$},
        'modified time looks like an epoch time';
    like $hash->{revision_id}, qr{^\d{14}$},
        'revision_id is correctly formatted';
    like $hash->{page_uri}, qr{/admin/index.cgi\?$page_id},
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
