#!/usr/bin/perl
# @COPYRIGHT@

use lib '../../../../..';
use strict;
use Socialtext::Search::KinoSearch::Analyzer::Ja::mecabif;

# This is not "use bytes"!!!
require bytes;
use Encode qw(encode_utf8);

binmode STDERR, ':utf8';

my $if = Socialtext::Search::KinoSearch::Analyzer::Ja::mecabif->new(
	dicdir => '../../../../../../share/l10n/mecab'
);
$if->{debug} = 1;

if (!@ARGV) {
    push @ARGV, "ja-test.data";
}
for my $infile (@ARGV) {
    unless (open I, "<$infile") {
	print STDERR "Cannot open $infile\n";
	next;
    }
    binmode I, ':utf8';
    my @result = $if->analyze(<I>);
    close I;
    print "@result\n";
}


