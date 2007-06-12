#!perl -Tw
# @COPYRIGHT@

use strict;
use warnings;

use Test::More skip_all => 'FIXME';

use Test::More tests => 1;

BEGIN {
    use_ok( 'Socialtext::Handler::Page' );
}
