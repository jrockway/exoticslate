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

my $hub = new_hub('admin');
my $viewer = $hub->viewer;

for my $test (@tests) {
    my $result = $viewer->text_to_html( $test->[0] );
    chomp(my $name = $test->[0]);
    like( $result, $test->[1], $name );
}
