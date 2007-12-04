#!/usr/bin/env perl
# -*- coding: utf-8 -*- vim:fileencoding=utf-8:
# @COPYRIGHT@
use strict;
use warnings;

use utf8;
use Test::Socialtext tests => 145;
fixtures( 'admin_no_pages' );


BEGIN { 
    unlink "t/tmp/etc/socialtext/socialtext.conf";
}

local *Socialtext::l10n::system_locale = sub {
   return 'ja';
};

use_ok("Socialtext::Search::KinoSearch::Factory");

our $workspace = 'admin';
our $hub = new_hub('admin');

#----------------------------------------------------------
# Testcases
#----------------------------------------------------------

SIMPLE_SEARCH: {
    erase_index_ok();
    make_page_ok(
        "ひらがな",
        "シリコンバレーの天気はいつも良好です"
    );
    search_ok( "シリコンバレー", 1, "Simple Hiragana search" );
    search_ok( "天気", 1, "Simple Kanji search" );
    search_ok( "ひらがな", 1, "Simple Hiragana word search (in title)" );

    make_page_ok(
        "ﾊﾝｶｸｶﾅ ﾊﾟｿｺﾝ",
        "今日はﾚﾎﾟｰﾄを書きました"
    );
    search_ok( "ﾚﾎﾟｰﾄ", 1, "Simple Hankaku-Kana Search" );
    search_ok( "ﾊﾟｿｺﾝ", 1, "Simple Hankaku-Kana Search (in tilte)" );

    make_page_ok(
        "ゼンカクカタカナ メロン",
        "ペンギンは北極にはいません"
    );
    search_ok( "ペンギン", 1, "Simple Zenkaku-Kana Search" );
    search_ok( "メロン", 1, "Simple Zenkaku-Kana Search (in title)" );

    make_page_ok(
        "ぜんかくひらがな りんご",
        "この夏はとまとをたくさん食べた",
    );
    search_ok( "とまと", 1, "Simple Zenkaku-Hiragana Search" );
    search_ok( "りんご", 1, "Simple Zenkaku-Hiragana Search (in tilte)" );

    make_page_ok(
        "全角漢字 市場",
        "経済の動向について調べる",
    );
    search_ok( "経済", 1, "Simple Zenkaku-Kanji Search" );
    search_ok( "市場", 1, "Simple Zenkaku-Kanji Search (in tilte)" );

    make_page_ok(
        "全角英数字 ＡＢＣ ３５７",
        "１３９０年にはＮＥＣはなかった",
    );
    search_ok( "１３９０", 1, "Simple Zenkaku-Number Search" );
    search_ok( "３５７", 1, "Simple Zenkaku-Number Search (in tilte)" );
    search_ok( "ＮＥＣ", 1, "Simple Zenkaku-Alphabet Search" );
    search_ok( "ＡＢＣ", 1, "Simple Zenkaku-Alphabet Search (in tilte)" );

    make_page_ok(
        "半角英数字 def 246",
        "2007年にはきっとSaleが始まるだろう"
    );
    search_ok( "2007", 1, "Simple Hankaku-Number Search" );
    search_ok( "246", 1, "Simple Hankaku-Number Search (in tilte)" );
    search_ok( "Sale", 1, "Simple Hankaku-Aplhabet Search" );
    search_ok( "def", 1, "Simple Hankaku-Alphabet Search (in tilte)" );
}

MORE_FEATURED_SEARCH: {
    erase_index_ok();
    make_page_ok( "Tom Stoppard", <<'QUOTE', [ "漢字", "ひらがな", "カタカナ"] );
シリコンバレーでの天気はいつも良好。
QUOTE
    search_ok(
        "シリコンバレー 天気", 1,
        "Assert searching defaults to AND connectivity"
    );
    search_ok( "tag:ひらがな", 1, "Tag search with word which is standalone" );
    search_ok( "tag:漢字", 1, "Tag search with word not also standalone" );
    search_ok( "tag:カタカナ", 1, "Tag search with word not also standalone" );
}

COMPOUND_SEARCH: {
    erase_index_ok();
    make_page_ok(
        "漢字の複合語 日本国憲法",
        "阪神高速道路公団は、阪高の管理団体です。東京都庁とはまったく関係ありません"
    );
    search_ok( "阪神高速道路公団", 1, "Compound Kanji Search 1" );
    search_ok( "阪神高速", 1, "Compound Kanji Search 2" );
    search_ok( "道路公団", 1, "Compound Kanji Search 3" );
    search_ok( "都庁", 1, "Compound Kanji Search 4" );
    search_ok( "東京", 1, "Compound Kanji Search 5" );
    search_ok( "日本国憲法", 1, "Compound Kanji Search (in title) 1" );
    search_ok( "憲法", 1, "Compound Kanji Search (in title) 2" );

    make_page_ok(
        "カタカナの複合語 スペシャルディナー",
        "ノーベル賞のスーパーカミオカンデについてはこちらまで。セキュリティシステム上、部外者には公開していません"
    );
    search_ok( "スーパーカミオカンデ", 1, "Compound Katakana Search 1" );
    search_ok( "カミオカンデ", 1, "Compound Katakana Search 2" );
    search_ok( "セキュリティ", 1, "Compound Katakana Search 3" );
    search_ok( "スペシャルディナー", 1, "Compound Katakana Search (in title) 1" );
    search_ok( "ディナー", 1, "Compound Katakana Search (in title) 2" );

    make_page_ok(
        "ひらがなの複合語 そばめし",
        "さぬきうどんは香川県の名物です"
    );
    search_ok( "さぬきうどん", 1, "Compound Hiragana Search 1" );
    search_ok( "さぬき", 1, "Compound Hiragana Search 2" );
    search_ok( "そばめし", 1, "Compound Hiragana Search (in title) 1" );
    search_ok( "そば", 1, "Compound Hiragana Search (in title) 2" );

    make_page_ok(
        "複合語 アカデミー賞",
        "２００２ＦＩＦＡワールドカップ、見ましたか？"
    );
    search_ok( "２００２ＦＩＦＡワールドカップ", 1, "Compound Complex Search 1" );
# NOT SUPPORTED
#    search_ok( "ＦＩＦＡ", 1, "Compound Complex Search 2" );
    search_ok( "ワールドカップ", 1, "Compound Complex Search 3" );
    search_ok( "アカデミー賞", 1, "Compound Complex Search (in title) 1" );
}

FORMATTED_STRING_SEARCH: {
    erase_index_ok();
    make_page_ok(
        "数値 0.15 \\300 \$153",
        "データ 123.45 122.55 111.31 \\150 \$100"
    );
    search_ok( "123.45", 1, "Decimal Search 1" );
    search_ok( "\\150", 1, "Decimal Search 2" );
    search_ok( "\$100", 1, "Decimal Search 3" );
    search_ok( "0.15", 1, "Decimal Search (in title) 1" );
    search_ok( "\\300", 1, "Decimal Search (in title) 2" );
    search_ok( "\$153", 1, "Decimal Search (in title) 3" );

    make_page_ok(
        "型番 XD-321 P_123",
        "データ A-123 A_123-1" 
    );
    search_ok( "A-123", 1, "Model Number Search 1" );
    search_ok( "A_123-1", 1, "Model Number Search 2" );
    search_ok( "XD-321", 1, "Model Number Search (in title) 1" );
    search_ok( "P_123", 1, "Model Number Search (in title) 2" );
}

STEM_CASE_SEARCH: {
    erase_index_ok();
    make_page_ok(
        "全角半角大文字小文字英字 1",
        "APPLEはりんごのことです",
    );
    make_page_ok(
        "全角半角大文字小文字英字  2",
        "appleはりんごのことです",
    );
    make_page_ok(
        "全角半角大文字小文字英字 3",
        "ＡＰＰＬＥはりんごのことです",
    );
    make_page_ok(
        "全角半角大文字小文字英字 4",
        "ａｐｐｌｅはりんごのことです",
    );
    make_page_ok(
        "全角半角大文字小文字英字 OrａＮge 5",
        "aPＰｌeはりんごのことです",
    );
    search_ok( "APPLE", 5, "Stem Case Search 1" );
    search_ok( "apple", 5, "Stem Case Search 2" );
    search_ok( "ＡＰＰＬＥ", 5, "Stem Case Search 3" );
    search_ok( "ａｐｐｌｅ", 5, "Stem Case Search 4" );
    search_ok( "aPＰｌe", 5, "Stem Case Search 5" );
    search_ok( "ORANGE", 1, "Stem Case Search (in title) 1" );
    search_ok( "orange", 1, "Stem Case Search (in title) 2" );
    search_ok( "ＯＲＡＮＧＥ", 1, "Stem Case Search (in title) 3" );
    search_ok( "ｏｒａｎｇｅ", 1, "Stem Case Search (in title) 4" );
    search_ok( "OrａＮge", 1, "Stem Case Search (in title) 5" );

    make_page_ok(
        "全角半角数字 856",
        "777はラッキーセブン",
    );
    make_page_ok(
        "全角半角数字 ８５６",
        "７７７はラッキーセブン",
    );
    search_ok( "777", 2, "Stem Case Search 1" );
    search_ok( "７７７", 2, "Stem Case Search 2" );
    search_ok( "856", 2, "Stem Case Search (in title) 1" );
    search_ok( "８５６", 2, "Stem Case Search (in title) 2" );

    make_page_ok(
        "送り仮名 組み合わせ",
        "たこ焼きは取扱いが難しい"
    );
    make_page_ok(
        "送り仮名 組合せ",
        "たこ焼は取扱が難しい"
    );
    search_ok( "取扱い", 2, "Stem Case Search 1" );
    search_ok( "取扱", 2, "Stem Case Search 2" );
    search_ok( "たこ焼", 2, "Stem Case Search 3" );
    search_ok( "たこ焼き", 2, "Stem Case Search 4" );
    search_ok( "組み合わせ", 2, "Stem Case Search (in title) 1" );
    search_ok( "組合せ", 2, "Stem Case Search (in title) 2" );

    make_page_ok(
        "異表記 バイオリン",
        "ラーメンには、すいかがあいますね。レビューしました?"
    );
    make_page_ok(
        "異表記 ヴァイオリン",
        "らーめんには、スイカがあいますね。レビュしました?"
    );
    search_ok( "ラーメン", 2, "Stem Case Search 1" );
    search_ok( "らーめん", 2, "Stem Case Search 2" );
    search_ok( "スイカ", 2, "Stem Case Search 3" );
    search_ok( "すいか", 2, "Stem Case Search 4" );
    search_ok( "レビュー", 2, "Stem Case Search 5" );
    search_ok( "レビュ", 2, "Stem Case Search 6" );
    search_ok( "バイオリン", 2, "Stem Case Search (in title) 1" );
    search_ok( "ヴァイオリン", 2, "Stem Case Search (in title) 2" );

    make_page_ok(
        "新旧字体 学校",
        "株式会社は株式を発行しています"
    );
    make_page_ok(
        "新旧字体 學校",
        "株式會社は株式を発行しています"
    );
    search_ok( "会社", 2, "Stem Case Search 1" );
    search_ok( "會社", 2, "Stem Case Search 2" );
    search_ok( "学校", 2, "Stem Case Search (in title) 1" );
    search_ok( "學校", 2, "Stem Case Search (in title) 2" );
}

OTHER_SEARCH: {
    erase_index_ok();

# NOT SUPPORTED
#    make_page_ok(
#        "ドットで接続された文字列 A.D.",
#        "E.L.T は Every Little Thing のことです"
#    );
#    make_page_ok(
#        "ドットで接続された文字列 Ａ．Ｄ．",
#        "Ｅ．Ｌ．Ｔ は Every Little Thing のことです"
#    );
#    search_ok( "E.L.T", 2, "Other Search 1" );
#    search_ok( "Ｅ．Ｌ．Ｔ", 2, "Other Search 2" );
#    search_ok( "A.D", 2, "Other Search (in title) 1" );
#    search_ok( "Ａ．Ｄ", 2, "Other Search (in title) 2" );

    make_page_ok(
        "句読点で終わる名詞句 がんばれ、ジャパン！",
        "モーニング娘。は、アイドルグループです。"
    );
    search_ok( "モーニング娘", 1, "Other Search 1" );
    search_ok( "モーニング娘。", 1, "Other Search 2" );
    search_ok( "ジャパン", 1, "Other Search (in title) 1" );

    make_page_ok(
        "ひらがなと句読点の連続 どない？",
        "ここをとおりゃんせ、おきゃくさん",
    );
    search_ok( "とおりゃんせ", 1, "Other Search 1" );
    search_ok( "どない", 1, "Other Search (in title) 1" );

    make_page_ok(
        "辞書にない新語、造語 みっくちゅじゅーす",
        "ドラえもんはみんなのアイドル",
    );
    search_ok( "ドラえもん", 1, "Other Search 1" );
    search_ok( "みっくちゅじゅーす", 1, "Other Search (in title) 1" );

    make_page_ok(
        "特殊文字  ㍼ 匍 凞 鸙",
        "特殊な漢字  ㈱    昻  喆で終わります"
    );
    search_ok( "㈱", 1, "Other Search  2" );
    search_ok( "昻", 1, "Other Search  3" );
    search_ok( "喆", 1, "Other Search  4" );
    search_ok( "㍼", 1, "Other Search (in title) 2" );
    search_ok( "匍", 1, "Other Search (in title) 3" );
    search_ok( "凞", 1, "Other Search (in title) 4" );
    search_ok( "鸙", 1, "Other Search (in title) 5" );
}

SPLITTED_WORD_BY_RETURN: {
    erase_index_ok();
    make_page_ok(
        "改行で分割された文字列1",
        "たとえば、当り前のことですが、この単語は辞書にあります。"
    );
    make_page_ok(
        "改行で分割された文字列2",
        "たとえば、当り\n前のことですが、この単語は辞\n書にあります。"
    );
    make_page_ok(
        "改行で分割された文字列3",
        "たとえば、当り\n\n前のことですが、この単語は辞\n\n書にあります。"
    );
    search_ok( "当り前", 3, "Splitted word Search 1" );
    search_ok( "辞書", 3, "Splitted word Search 1" );
}

ENGLISH: {
    erase_index_ok();
    make_page_ok(
        "英語でかかれた文書です",
        "This document is not good. Japanese is good.\nThis document is good."
    );
    search_ok( "Japanese", 1, "English Word Search 1" );
}

#----------------------------------------------------------
# Utility methods
#----------------------------------------------------------
sub make_page_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ( $title, $content, $tags ) = @_;
    my $page = $hub->pages->new_from_name($title);
    $page->update(
        user             => $hub->current_user,
        subject          => $title,
        content          => $content,
        categories       => $tags || [],
        original_page_id => $page->id,
        revision         => $page->metadata->Revision || 0,
    );
    index_ok( $page->id );

    return $page;
}

sub search_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ( $term, $num_of_results, $text ) = @_;
    my @results = eval { searcher()->search($term) };
    diag($@) if $@;

    my $hits = ( $num_of_results == 1 ) ? "hit" : "hits";
    is(
        scalar @results,
        $num_of_results,
        "'$term' returns $num_of_results $hits: $text"
    );

    return @results;
}

sub index_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $INDEX_MAX = 60;    # 60 seconds to index a page.

    my $page = shift;
    my $id   = ref($page) ? $page->id : $page;

    # Use a double eval in case the alarm() goes off in between returing from
    # the inner eval and before alarm(0) is executed.
    my $fail;
    eval {
        local $SIG{ALRM} = sub {
            die "Indexing $id is taking more than $INDEX_MAX seconds.\n";
        };
        alarm($INDEX_MAX);
        eval { 
            indexer()->index_page($id);
        };
        $fail = $@;
        alarm(0);
    };

    diag("ERROR Indexing $id: $fail\n") if $fail;
    ok( not($fail), "Indexing $id" );
}

sub erase_index_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    eval { indexer()->delete_workspace($workspace) };
    diag("erase_index_ok: $@\n") if $@;
    ok( not($@), "============ ERASED INDEX =============" );
}

sub searcher {
    Socialtext::Search::KinoSearch::Factory->create_searcher($workspace);
}

sub indexer {
    Socialtext::Search::KinoSearch::Factory->create_indexer($workspace);
}
