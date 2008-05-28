#!perl -w
# @COPYRIGHT@

use strict;
use warnings;

use Test::More tests => 9;

BEGIN {
    use_ok( 'Socialtext::String' );
}

TRIM: {
    is( Socialtext::String::trim( '   12 x   34   ' ), '12 x   34', 'leading and trailing spaces' );
    is( Socialtext::String::trim( '123  4   ' ), '123  4', 'trailing spaces' );
    is( Socialtext::String::trim( '    1234' ), '1234', 'leading spaces' );
    is( Socialtext::String::trim( '12 34' ), '12 34', 'no extra spaces' );
    is( Socialtext::String::trim( '1 2    3 4' ), '1 2    3 4', 'no extra spaces' );
    is( Socialtext::String::trim( '' ), '', 'empty strings ');
}

URI_ESCAPE: {
    is( Socialtext::String::uri_escape('asd fds'), 'asd%20fds', 'uri_escape' );
}

DOUBLE_SPACE_HARDEN: {
    is( Socialtext::String::double_space_harden('a b  c    d'),
        "a b \x{00a0}c \x{00a0} \x{00a0}d",
        'double_space_harden' );
}


