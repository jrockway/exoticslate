#!/usr/bin/env perl
# -*- coding: utf-8 -*- vim:fileencoding=utf-8:
# @COPYRIGHT@
use strict;
use warnings;

{ # XXX - Someone japanese needs to fix these tests
    use Test::More skip_all => 'Japanese search tests are broken';
    exit;
}

use utf8;
use File::Find;

use Test::Socialtext tests => 66;
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
our $target_ext = 'txt';

#----------------------------------------------------------
# Testcases
#----------------------------------------------------------

PLAIN_TEXT_ATTACHMENT_SEARCH: {
    erase_index_ok();
    $target_ext =  'txt';
    make_page_ok(
        "添付ファイルのテスト文書(plain text)",
        "添付ファイルのバリエーションテストです。",
    );
    search_ok( "東京", 1, "Shift_JIS text search" );
    search_ok( "大阪", 1, "EUC text search" );
    search_ok( "神戸", 1, "JIS text search" );
    search_ok( "広島", 1, "UTF8 no BOM text search" );
    search_ok( "松山", 1, "UTF8 with BOM text search" );
    search_ok( "Japanese", 0, "ascii text search" );
    search_ok( "札幌", 0, "UTF16 text search" );
    search_ok( "document", 0, "ISO-8859-1 text search" );
    search_ok( "仙台", 0, "GB2312 text search" );
}

WORD_ATTACHMENT_SEARCH: {
    erase_index_ok();
    $target_ext =  'doc';
    make_page_ok(
        "添付ファイルのテスト文書(word)",
        "添付ファイルのバリエーションテストです。",
    );
    search_ok( "北海道", 1, "Word2003 text search" );
}

EXCEL_ATTACHMENT_SEARCH: {
    erase_index_ok();
    $target_ext =  'xls';
    make_page_ok(
        "添付ファイルのテスト文書(excel)",
        "添付ファイルのバリエーションテストです。",
    );
    search_ok( "中国", 1, "Excel2003 text search" );
}

POWERPOINT_ATTACHMENT_SEARCH: {
    erase_index_ok();
    $target_ext =  'ppt';
    make_page_ok(
        "添付ファイルのテスト文書(powerpoint)",
        "添付ファイルのバリエーションテストです。",
    );
    search_ok( "四国", 1, "PowerPoint2003 text search" );
}

PDF_ATTACHMENT_SEARCH: {
    erase_index_ok();
    $target_ext =  'pdf';
    make_page_ok(
        "添付ファイルのテスト文書(pdf)",
        "添付ファイルのバリエーションテストです。",
    );
    search_ok( "九州", 1, "PDF text search" );
}

RTF_ATTACHMENT_SEARCH: {
    erase_index_ok();
    $target_ext =  'rtf';
    make_page_ok(
        "添付ファイルのテスト文書(rtf)",
        "添付ファイルのバリエーションテストです。",
    );
    search_ok( "名古屋", 1, "RTF text search" );
}

ZIP_ATTACHMENT_SEARCH: {
    erase_index_ok();
    $target_ext =  'zip';
    make_page_ok(
        "添付ファイルのテスト文書(zip)",
        "添付ファイルのバリエーションテストです。",
    );
    search_ok( "青森", 1, "ZIP text search (plain)" );
    search_ok( "岩手", 1, "ZIP text search (plain)" );
    search_ok( "秋田", 1, "ZIP text search (excel)" );
    search_ok( "山形", 1, "ZIP text search (powerpoint)" );
}

HTML_ATTACHMENT_SEARCH: {
    erase_index_ok();
    $target_ext =  'html';
    make_page_ok(
        "添付ファイルのテスト文書(html)",
        "添付ファイルのバリエーションテストです。",
    );
    search_ok( "Chinese", 1, "ascii html text search" );
    search_ok( "鳥取", 1, "utf8 html text search" );
    search_ok( "島根", 1, "shift_jis html text search" );
}

XML_ATTACHMENT_SEARCH: {
    erase_index_ok();
    $target_ext =  'xml';
    make_page_ok(
        "添付ファイルのテスト文書(xml)",
        "添付ファイルのバリエーションテストです。",
    );
    search_ok( "金沢", 1, "utf8 xml text search" );
    search_ok( "French", 1, "ascii xml text search" );
    search_ok( "長野", 1, "shift-jis xml text search" );
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

    our @filename = ();
    my $target_dir = 't/attachments/l10n/ja-search/';
    find (\&push_filename, $target_dir);

    sub push_filename {
        if ( $_ =~ /${target_ext}$/ ){
            push @filename, $_;
        }
    }

    foreach ( @filename ){
        my $filepath = $target_dir . $_;
        open my $fh, $filepath or die "unable to open $filepath: $!";
        my $attachment = $hub->attachments->create(
            filename => $_,
            fh => $fh,
            creator => $hub->current_user,
            page_id => $page->id,
        );
        index_attachment_ok( $page->id, $attachment->id );
    }

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


sub index_attachment_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $INDEX_MAX = 60;    # 60 seconds to index a page.

    my $page = shift;
    my $attachment = shift;
    my $page_id   = ref($page) ? $page->id : $page;
    my $attachment_id   = ref($attachment) ? $attachment->id : $attachment;

    # Use a double eval in case the alarm() goes off in between returing from
    # the inner eval and before alarm(0) is executed.
    my $fail;
    eval {
        local $SIG{ALRM} = sub {
            die "Indexing $attachment_id is taking more than $INDEX_MAX seconds.\n";
        };
        alarm($INDEX_MAX);
        eval { 
            indexer()->index_attachment($page_id, $attachment_id);
        };
        $fail = $@;
        alarm(0);
    };

    diag("ERROR Indexing $attachment_id: $fail\n") if $fail;
    ok( not($fail), "Indexing $attachment_id" );
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
