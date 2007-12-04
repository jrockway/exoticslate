#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;

my ($testcnt, @testcase);
BEGIN {
    my $infile = 't/test-data/ja/mecabif.in';
    open I, '<', $infile;
    binmode I, ':utf8';
    @testcase = <I>;
    $testcnt = 2 + scalar @testcase;
    close I;
}

use Test::Socialtext tests => $testcnt;
use Socialtext::AppConfig;
use File::Spec::Functions qw(catdir);
use Encode qw(encode_utf8 decode_utf8);

my $config = Socialtext::AppConfig->new;
my $sharedir = $config->code_base;
my $dicdir = catdir( $sharedir, "l10n", "mecab" );

SKIP: {

# Try to load the mecab stuff, but this may fail if you're not setup for
# Japanese loving.
eval { require Socialtext::Search::KinoSearch::Analyzer::Ja::Tokenize };
if ( $@ or not -e "$dicdir/char.bin" ) {
    skip "Could not initialize mecab data.", $testcnt;
}

use_ok("Socialtext::Search::KinoSearch::Analyzer::Ja::mecabif");

my $if = Socialtext::Search::KinoSearch::Analyzer::Ja::mecabif->new(
	dicdir => $dicdir
);

isa_ok($if, 'Socialtext::Search::KinoSearch::Analyzer::Ja::mecabif');

for (@testcase) {
    chomp;
    my ($feed, @words) = split(/\t/, $_);
    my %check;
    my $bad = 0;
    for (@words) {
	$check{$_} = 1;
    }
    my $orig = $feed;
    my @result = map { decode_utf8($_) } $if->analyze($feed);
    for (@result) {
	# next if (/^\s+$/);
	if (!exists $check{$_}) {
	    $bad++;
	}
    }

    # I highly suspect that test framework can use some improvements
    # when giving the error message.  Under -v option, ok N - <msg>
    # seems to expect <msg> to be in Perl internal character, but
    # when it is shown as error, the msssage wants it to be encoded
    # otherwise we will see "Wide character in print" errors.
    # Sheesh.
    if (!$bad) {
	ok(!$bad, "'$orig' should split to " .
	   join(', ', map { "'$_'" } @words));
    } else {
	my $however = ", however it split to " .
	    join(', ', map { encode_utf8("'$_'") } @result);
	ok(!$bad, encode_utf8("'$orig' should split to ") .
	   join(', ', map { encode_utf8("'$_'") } @words) .
	   $however);
    }
}
}
