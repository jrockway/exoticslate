#!perl
# @COPYRIGHT@
use strict;
use warnings;
use lib 't/lib';
use Test::WikiText;

plan tests => 1;

#no_diff;

$Test::WikiText::parser_module =
    'Socialtext::WikiText::Parser';
$Test::WikiText::emitter_module =
    'Socialtext::WikiText::Emitter::SearchSnippets';;

filters({wikitext => 'parse_wikitext'});

run_is 'wikitext' => 'snippet';

__DATA__
=== Multiline Paragraphs

--- wikitext
this is a multiline blob of
text that should be in a
single paragraph

but this should be alone

--- snippet
this is a multiline blob of text that should be in a single paragraph but this should be alone
