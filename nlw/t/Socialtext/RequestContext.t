#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 1;
fixtures( 'admin_no_pages' );

BEGIN {
    use_ok( 'Socialtext::RequestContext' );
}
