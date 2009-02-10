#!perl -w
# @COPYRIGHT@

use strict;
use warnings;

use Test::More tests => 19;

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

WORD_TRUNCATE: {
    is Socialtext::String::word_truncate('abcd', 15), 'abcd',
        'no ellipsis on short label';
    is Socialtext::String::word_truncate('abcd', 2), 'ab...',
        'Ellipsis on length 2 label';
    is Socialtext::String::word_truncate('abc def', 4), 'abc...',
        'Ellipsis breaks on space';
    is Socialtext::String::word_truncate('abc def', 6), 'abc...',
        'Ellipsis breaks on space if short one';
    is Socialtext::String::word_truncate('abc def', 7), 'abc def',
        'No ellipsis on exact length';
    is Socialtext::String::word_truncate('abc  def efg', 11), 'abc  def...',
        'Whitespace preserved between words';
    is Socialtext::String::word_truncate('abc def', 0), '...',
        'Ellipsis only if length is 0';
    is Socialtext::String::word_truncate('abc def', 2), 'ab...',
        'Proper short word ellipsis with space';

    my $singapore = join '', map { chr($_) } 26032, 21152, 22369;
    is Socialtext::String::word_truncate($singapore, 3), $singapore,
        'UTF8 not truncated';
    is Socialtext::String::word_truncate($singapore, 2),
        substr($singapore, 0, 2) . '...', 'UTF8 truncated with ellipsis';
}
