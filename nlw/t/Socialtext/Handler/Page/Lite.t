#!perl -Tw
# @COPYRIGHT@

use Test::More skip_all => 'FIXME';

use strict;
use warnings;
use Test::More tests => 1;

BEGIN {
    use_ok( 'Socialtext::Handler::Page::Lite' );
}
