#!perl
# @COPYRIGHT@

use warnings;
use strict;
use Test::Socialtext tests => 4;
fixtures( 'admin_no_pages' );

BEGIN {
    use_ok( 'Socialtext::Pages' );
}

my $hub = new_hub('admin');
isa_ok( $hub, 'Socialtext::Hub' );

CREATE_NEW_PAGE: {
    my $page = $hub->pages->create_new_page();

    ok($page->isa('Socialtext::Page'), 'object is a Socialtext Page');
    like($page->title, qr/^devnull1/, 'title starts with the right name');
}


