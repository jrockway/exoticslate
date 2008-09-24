package Socialtext::Search::KinoSearch::Analyzer::Ja::mecabif;
use strict;
# @COPYRIGHT@

use Encode qw(decode_utf8 encode_utf8 encode decode);
use Text::MeCab;

sub new {
	# This should not say 'use utf8' as it would slow down
	# the regexp match to read from mecab considerbaly.

	my $class = shift;
	$class = ref $class if ref $class;
	my $self = bless {}, $class;
	my %attr = @_;

	# We reuse a same MeCab instance.  It eats Japanese text
	# stream (use Juman dictionary with it), and tokenizes
	# into runs of words, while annotating what kind of word
	# each of them is and what the "canonical" spelling of
	# the word is.  The latter is of most interest, as we can
	# do away without the stemmer.

	$self->{mecab} = Text::MeCab->new({
		output_format_type => 'user',
		node_format => join('\t',
				    ("NODE",	# for easier parsing
				     "%m",	# input word
				     "%f[0]",	# word type
				     "%f[6]",	# auxiliary information
				     )),
		%attr,
	});

	# Many of the words in Japanese are not "interesting" while
	# building indices or performing a search.  Instead of using the
	# word order to differenciate different "cases" (e.g.  nominative,
	# accusative, etc.), Japanese have a class of suffixes that attach
	# to nouns to mark which case the noun is used in the sentence,
	# and they are usually of no interest for text search purposes.
	# This lists the word types that are of interest.

	$self->{unhandled_types} = +{
		map { $_ => 1 }
		("指示詞", "特殊", "判定詞")
	    };

	# The most important part of the auxiliary information
	# is the "canonical" spelling definition, which follows
	# this prefix in the MeCab output.
	$self->{canon_label} = "代表表記:";

	return $self;
}

# MeCab unfortunately does too much.  When given a typical Japanese
# text that has a few English words, URLs and such sprinkled in,
# it removes the punctuation and separates them into words of
# unknown category.  We replace ASCII sequences into stub upfront
# before passing the input to MeCab, and when we read its output back
# replace the stubs into the original, to be processed further with
# Latin rules.
sub replace_ascii {
    my ($token, $ascii_token) = @_;
    my @ret = ();
    while ($token =~ /<<(\d+)>>(.*)/) {
	push @ret, $ascii_token->[$1];
	$token = $2;
    }
    if ($token ne "") {
	push @ret, $token;
    }
    return @ret;
}

sub handle_morph {
	my $self = shift;
	my ($text, $ascii_token) = @_;

	my $mecab = $self->{mecab};
	my $canon_label = $self->{canon_label};
	my $unhandled_types = $self->{unhandled_types};

	my $node = $mecab->parse($text);
	my @ret;
	my $in_ascii = '';
	while ($node) {
		my $parsed = $node->format($mecab);
		chomp($parsed);
		my ($n, $word, $type, $aux) = split(/\t/, $parsed);
		$node = $node->next;
		if ($self->{debug} && $parsed ne '') {
			my $d = decode_utf8($parsed);
			print STDERR "MECAB: $d\n";
		}
		next unless (defined $n && $n eq 'NODE');
		if ($word =~ /^[ -~]*$/) {
			# ASCII
			$in_ascii .= $word;
			next;
		}
		next if (exists $unhandled_types->{$type});
		if ($aux =~ /$canon_label(\S+)/o) {
			$word = $1;
		}

		if ($in_ascii ne '') {
			push @ret, replace_ascii($in_ascii, $ascii_token);
		}
		$in_ascii = '';
		push @ret, $word;
	}
	if ($in_ascii ne '') {
		push @ret, replace_ascii($in_ascii, $ascii_token);
	}
	if ($self->{debug}) {
		my $ix = 0;
		print STDERR "ANALYSIS\n";
		for (@ret) {
			$ix++;
			my $d = decode_utf8($_);
			print STDERR "$ix: $d\n";
		}
	}
	return map { decode_utf8($_) } @ret;
}

our (%H2Z, $H2Z, %H2Z0, $H2Z0, %H2Z1, $H2Z1);
sub add_h2z {
	my ($hash, $decode_e) = @_;
	$decode_e ||= '';

	while (my ($key, $val) = each %$hash) {
		if ($decode_e eq 'e') {
			$key = decode('euc-jp', $key);
			$val = decode('euc-jp', $val);
		}
		elsif ($decode_e eq 'k') {
			$key = decode_utf8($key);
		}
		$H2Z{$key} = $val;
		$H2Z .= (defined $H2Z ? '|' : '') . quotemeta($key);
	}
}

sub add_h2z_str {
	my ($from, $to) = @_;
	my $l = length($from);
	if (length($to) != $l) { die "OOPS $from => $to???"; }
	my %h = ();
	for (my $i = 0; $i < $l; $i++) {
		$h{substr($from, $i, 1)} = substr($to, $i, 1);
	}
	add_h2z(\%h);
}

BEGIN {
	use Encode::JP::H2Z ();
	use utf8;

	# Data borrowed from this module is in EUC-JP and
	# needs to be converted.
	#
	# - %Encode::JP::H2Z:_D2Z maps split-char in H to Z
	# - %Encode::JP::H2Z:_H2Z maps H to Z
	#
	# D2Z needs to be applied first and then H2Z.
	add_h2z(\%Encode::JP::H2Z::_D2Z, 'e');
	add_h2z(\%Encode::JP::H2Z::_H2Z, 'e');
	%H2Z0 = %H2Z; $H2Z0 = $H2Z; %H2Z = (); $H2Z = undef;

	# "Violin" and friends.
	add_h2z(+{
		'ヴァ' => 'バ', 'ヴィ' => 'ビ', 'ヴュ' => 'ブ',
		'ヴゥ' => 'ブ',	'ヴェ' => 'べ',	'ヴォ' => 'ボ',
	});
	%H2Z1 = %H2Z; $H2Z1 = $H2Z; %H2Z = (); $H2Z = undef;

	add_h2z_str('ァィゥェォ', 'アイウエオ');

	# ASCII
	add_h2z_str('０１２３４５６７８９：；＜＝＞？', '0123456789:;<=>?');
	add_h2z_str('＠ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯ', '@ABCDEFGHIJKLMNO');
	add_h2z_str('ＰＱＲＳＴＵＶＷＸＹＺ［￥］＾＿', 'PQRSTUVWXYZ[\\]^_');
	add_h2z_str('ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏ', 'abcdefghijklmno');
	add_h2z_str('ｐｑｒｓｔｕｖｗｘｙｚ｛｜｝', 'pqrstuvwxyz{|}');

	# These are so-called "platform specific" idiosynchracies;
	# normalize them to be readable everywhere.
	add_h2z(+{
		"\342\221\240" => '(1)',
		"\342\221\241" => '(2)',
		"\342\221\242" => '(3)',
		"\342\221\243" => '(4)',
		"\342\221\244" => '(5)',
		"\342\221\245" => '(6)',
		"\342\221\246" => '(7)',
		"\342\221\247" => '(8)',
		"\342\221\250" => '(9)',
		"\342\221\251" => '(10)',
		"\342\221\252" => '(11)',
		"\342\221\253" => '(12)',
		"\342\221\254" => '(13)',
		"\342\221\255" => '(14)',
		"\342\221\256" => '(15)',
		"\342\221\257" => '(16)',
		"\342\221\260" => '(17)',
		"\342\221\261" => '(18)',
		"\342\221\262" => '(19)',
		"\342\221\263" => '(20)',
		"\342\205\240" => 'I',
		"\342\205\241" => 'II',
		"\342\205\242" => 'III',
		"\342\205\243" => 'IV',
		"\342\205\244" => 'V',
		"\342\205\245" => 'VI',
		"\342\205\246" => 'VII',
		"\342\205\247" => 'VIII',
		"\342\205\250" => 'IX',
		"\342\205\251" => 'X',
		"\342\205\260" => 'i',
		"\342\205\261" => 'ii',
		"\342\205\262" => 'iii',
		"\342\205\263" => 'iv',
		"\342\205\264" => 'v',
		"\342\205\265" => 'iv',
		"\342\205\266" => 'vii',
		"\342\205\267" => 'viii',
		"\342\205\270" => 'ix',
		"\342\205\271" => 'x',
		"\343\215\211" => 'ミリ',
		"\343\214\224" => 'キロ',
		"\343\214\242" => 'センチ',
		"\343\215\215" => 'メートル',
		"\343\214\230" => 'グラム',
		"\343\214\247" => 'トン',
		"\343\214\203" => 'アール',
		"\343\214\266" => 'ヘクタール',
		"\343\215\221" => 'リットル',
		"\343\215\227" => 'ワット',
		"\343\214\215" => 'カロリー',
		"\343\214\246" => 'ドル',
		"\343\214\243" => 'セント',
		"\343\214\253" => 'パーセント',
		"\343\215\212" => 'ミリバール',
		"\343\214\273" => 'ページ',
		"\343\216\234" => 'mm',
		"\343\216\235" => 'cm',
		"\343\216\236" => 'km',
		"\343\216\216" => 'mg',
		"\343\216\217" => 'kg',
		"\343\217\204" => 'cc',
		"\343\216\241" => 'm2',
		"\343\215\273" => '平成',
		"\342\204\226" => 'No.',
		"\343\217\215" => 'K.K.',
		"\342\204\241" => 'TEL',
		"\343\212\244" => '(上)',
		"\343\212\245" => '(中)',
		"\343\212\246" => '(下)',
		"\343\212\247" => '(左)',
		"\343\212\250" => '(右)',
		"\343\210\261" => '(株)',
		"\343\210\262" => '(有)',
		"\343\210\271" => '(代)',
		"\343\215\276" => '明治',
		"\343\215\275" => '大正',
		"\343\215\274" => '昭和',
		"\343\200\200" => ' ',
		"\357\274\201" => '!',
		"\342\200\235" => '"',
		"\357\274\203" => '#',
		"\357\274\204" => '$',
		"\357\274\205" => '%',
		"\357\274\206" => '&',
		"\357\277\245" => '\\',
		"\342\200\231" => '\'',
		"\357\274\210" => '(',
		"\357\274\211" => ')',
		"\357\274\212" => '*',
		"\357\274\213" => '+',
		"\357\274\214" => ',',
		"\357\274\215" => '-',
		"\357\274\216" => '.',
		"\357\274\217" => '/',
	}, 'k');
}

sub analyze {
	my $self = shift;
	my (@ascii_token, @all, $text);

	for (@_) {
		# Replace controls to SP, except CR/LF
		s/([\000-\011\013\014\016- ]+)/ /g;
		s/([\012\015]+)/\012/g;

		# Run H2Z for Kana, and stuff.
		s/($H2Z0)/(exists $H2Z0{$1} ? $H2Z0{$1} : $1)/ego;
		s/($H2Z1)/(exists $H2Z1{$1} ? $H2Z1{$1} : $1)/ego;
		s/($H2Z)/(exists $H2Z{$1} ? $H2Z{$1} : $1)/ego;

		# Splice them into ASCII sequence and others,
		# and replace ASCII sequences with stubs.
		while (/^(.*?)([!-~]+)(.*)$/s) {
			my ($na, $a, $rest) = ($1, $2, $3);
			push @all, $na;
			push @all, (" <<" . scalar(@ascii_token) . ">> ");
			push @ascii_token, $a;
			$_ = $rest;
		}
		if ($_ ne '') {
			# Japanese string.  Remove LF, because a
			# single word could be split across physical
			# lines, in which case we would want to join
			# them back.
			s/[\012]+//g;
			push @all, $_;
		}
	}
	$text = join('', @all);

	return map { encode_utf8($_) }
		$self->handle_morph($text, \@ascii_token);
}

1;
