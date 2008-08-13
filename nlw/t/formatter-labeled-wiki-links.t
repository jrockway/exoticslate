#!perl
# @COPYRIGHT@

use warnings;
use strict;

use Test::Socialtext;
fixtures('admin');

my $renamed_hint = '<!-- wiki-renamed-link SomePage -->';
my @tests =
    ( [ qq|"A label"[SomePage]\n| =>
        qr(href="[^"]+SomePage[^"]*"[^>]*>A label$renamed_hint</a>) ],
      [ qq|"A label with space after" [SomePage]\n| =>
        qr(href="[^"]+SomePage[^"]*"[^>]*>A label with space after$renamed_hint</a>) ],
      [ qq|[NoLabel]\n| =>
        qr(href="[^"]+NoLabel[^"]*"[^>]*>NoLabel</a>) ],
    );

plan tests => scalar @tests;

for my $test (@tests) {
    formatted_like $test->[0], $test->[1];
}
