#!/usr/bin/evn perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::More tests => 1;

SKIP: {
    skip 'No `gr` available', 1, unless `which gr` =~ /\w/;

    chomp( my $blanks
      = `gr -l about:blank * | grep -v share/selenium/scripts | grep -v t/about-blank.t | wc -l` );

    cmp_ok($blanks, '==', 0, 'No about:blank in our source code');
};

