#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 2;
fixtures( 'admin_no_pages' );

BEGIN {
    use_ok( 'Socialtext::WeblogPlugin' );
}

WEBLOG_CACHE: {
    my $hub = new_hub('admin');

    $hub->weblog->current_weblog('socialtext blog');
    $hub->weblog->update_current_weblog();
    is $hub->weblog->current_blog, 'socialtext blog',
        'cache is written with socialtext blog';
}
