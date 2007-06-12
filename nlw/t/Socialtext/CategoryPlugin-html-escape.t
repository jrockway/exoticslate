#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 1;
use utf8;
use Socialtext::Pages;
use YAML;

package MockMetadata;
sub Category { [ 'Useless Info', 'Odds & Ends', 'Blöde' ] }

package main;

my $page = bless {
    metadata => bless {}, 'MockMetadata',
}, 'Socialtext::Page';

my $expected = "---
- Blöde
- Odds &amp; Ends
- Useless Info
";

is YAML::Dump([$page->html_escaped_categories]), $expected,
    'html_escaped_categories';
