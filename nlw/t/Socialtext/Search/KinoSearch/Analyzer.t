#!/usr/bin/env perl
# -*- coding: utf-8 -*- vim:fileencoding=utf-8:
# @COPYRIGHT@
use strict;
use warnings;

use utf8;
use Test::Socialtext tests => 52;

BEGIN { use_ok("Socialtext::Search::KinoSearch::Analyzer") }
require bytes;
use Data::Dumper;
use Encode qw(decode_utf8);
use KinoSearch::Analysis::TokenBatch;


TOKENIZE_BASIC: {
    token_count_ok( 'en', "My cow's love is perfect",              5 );
    token_count_ok( 'en', "Groß français cow's español",        4 );
    token_count_ok( 'en', "Socialtext Version 2.0.1.3 rocks",      4 );
    token_count_ok( 'en', "Foobar Version 2.1 is great",           5 );
    token_count_ok( 'en', "cows abc123 2.1.x like crap",           6 );
    token_count_ok( 'en', "Part 3245lk234-1234h3214-34kk3142 sux", 3 );
    token_count_ok( 'en', "X" x 100000, 0 );
}

LOWERCASE_ANALYZER: {
    my @tokens = token_count_ok(
        'en',
        'FoO BaR BaZ COWS like The man MadE oF FLAn', 10
    );
    for my $token (@tokens) {
        like( $token, qr/^[a-z]+$/, "Lower case token ($token)" );
    }
}

ANALYZE_SPECIALS: {
    tokens_contain_what_i_want(
        'en', <<'TEST_STR',
foo 2.0.1.3 with part 1234lkj-1324lkj-23k $10.23 -100.4 8.82% .40% $100 €100 and I like the website 43folders
TEST_STR
        '2.0.1.3'             => 'Version numbers are analyzed',
        '1234lkj-1324lkj-23k' => 'Part numbers are analyzed',
        '$100'                => 'Tokens with sigil $ are matched.',
        '€100'                => 'Tokens with sigil € are matched.',
        '$10.23'              => 'Tokens with sigil $ are matched.',
        '-100.4'              => 'Tokens with sigil - are matched.',
        '8.82%'               => 'Tokens with sigil % are matched.',
        '.40%'                => 'Tokens with sigil % are matched (<1).',
        '43folder'            => 'Tokens with alphanumerics',
    );

    tokens_do_not_contain_what_i_want(
        'en', <<'TEST_STR',
You owe: -$100.0  Or in quebec: 100$ %40 
TEST_STR
        '-$100.0' => 'Tokens with negative dollars',
        '%40'     => 'Tokens with backwards percent',
        '100$'    => 'Tokens with french dollars',
    );
}

DO_NO_CRUSH_UUIDS: {
    tokens_contain_what_i_want(
        'en',
        "My fav uuid is 0xc274ff2283fa11dbb097e70c1655db39 it rules.",
        '0xc274ff2283fa11dbb097e70c1655db39' => "UUID isn't mangled",
    );
}

STEMS_FROM_THE_PORTUGUESE: {
    token_count_ok( 'pt', 'Ela fecha sempre a janela antes de janta', 8 );
    token_count_ok( 'pt', 'Nos fortes corações, na grande estrela', 6 );
    token_count_ok( 'pt', 'corações, quilométricas 2.5.4 estrela', 4 );
    tokens_contain_what_i_want(
        'pt', 'Nos fortes corações, na grande estrela',
        nos        => "Nos -> nos",
        fort       => 'fortes -> fort',
        "coraçõ" => 'corações, -> coraçõ',
        na         => 'na -> na',
        grand      => 'grande => grand',
        estrel     => 'estrela -> estrel',
    );
    tokens_contain_what_i_want(
        'pt', 'cows like quilométricas',
        "quilométr" => "quilométricas -> quilométr"
    );
}

STEMS_FROM_THE_PORTUGUESE_AS_ENGLISH: {
    token_count_ok( 'en', 'Ela fecha sempre a janela antes de janta', 8 );
    token_count_ok( 'en', 'Nos fortes corações, na grande estrela', 6 );
    token_count_ok( 'en', 'corações, quilométricas 2.5.4 estrela', 4 );
    tokens_contain_what_i_want(
        'en', 'Nos fortes corações, na grande estrela',
        nos        => "Nos -> nos",
        fort       => 'fortes -> fort',
        "coraçõ" => 'corações, -> coraçõ',
        na         => 'na -> na',
        grand      => 'grande => grand',
        estrela    => 'estrela -> estrela',
    );
    tokens_contain_what_i_want(
        'en', 'cows like quilométricas',
        "quilométrica" => "quilométricas -> quilométrica"
    );
}

sub tokens_contain_what_i_want {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my ( $lang, $text, %matches ) = @_;
    my @tokens = analyze( $lang, $text );
    for my $wanted_token ( sort keys %matches ) {
        my $contained = grep { $wanted_token eq $_ } @tokens;
        ok( $contained, $matches{$wanted_token} );
        diag( "Did not find $wanted_token in " . Dumper( \@tokens ) )
            unless $contained;
    }
}

sub tokens_do_not_contain_what_i_want {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my ( $lang, $text, %matches ) = @_;
    my @tokens = analyze( $lang, $text );
    for my $wanted_token ( sort keys %matches ) {
        my $contained = grep { $wanted_token eq $_ } @tokens;
        ok( not($contained), $matches{$wanted_token} );
        diag( "Found $wanted_token in " . Dumper( \@tokens ) )
            if $contained;
    }
}

sub token_count_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my ( $lang, $text, $count ) = @_;
    my @tokens = analyze( $lang, $text );
    is( scalar(@tokens), $count, "'$text' has $count tokens." );
    return @tokens;
}

sub analyze {
    my ( $lang, $text ) = @_;
    my $a = Socialtext::Search::KinoSearch::Analyzer->new( language => $lang );
    my $batch = KinoSearch::Analysis::TokenBatch->new;

    $batch->append( $text, 0, bytes::length($text) );
    $batch = $a->analyze($batch);

    my @tokens;
    while ( $batch->next ) {
        push @tokens, decode_utf8( $batch->get_text );
    }

    return @tokens;
}
