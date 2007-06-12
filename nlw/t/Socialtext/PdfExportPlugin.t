#!perl
# @COPYRIGHT@

# These tests provide a very simple and inadequate regression
# test to confirm that the output from the PdfExportPlugin is PDF.
# More exhaustive tests would be nice if we could figure out a
# good way to do it...

use warnings;
use strict;

use Test::Socialtext tests => 11;
fixtures('admin');

use Readonly;
use YAML;

BEGIN {
    use_ok('Socialtext::PdfExportPlugin');
}

Readonly my $PAGE_NAME => 'Admin Wiki';
Readonly my $HUB       => new_hub('admin');

my @cases = Load(join '', <DATA>);

generates_valid_pdf(@$_) for @cases;

sub generates_valid_pdf {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my ( $wikitext, $description ) = @_;
    $description ||= $wikitext;

    my $pdf_content = pdf_for_wikitext($wikitext);
    like(
        $pdf_content, qr/\A%PDF-\d+\.\d+/,
        "$description looks like a pdf at start"
    );
    like(
        $pdf_content, qr/%%EOF\Z/,
        "$description looks like a pdf at end"
    );
}

MULTI_PAGE: {
    my @page_names = ('Conversations', 'Start Here', 'Meeting agendas');

    my $pdf_content;
    $HUB->pdf_export->multi_page_export( \@page_names, \$pdf_content );

    like(
        $pdf_content, 
        qr/\A%PDF-\d+\.\d+/,
        'generated content looks like a pdf at start'
    );
    like(
        $pdf_content, 
        qr/%%EOF\Z/,
        'generated content looks like a pdf at end'
    );
}

HTML_FILES: {
    my $filename = $HUB->pdf_export->_create_html_file( 'Conversations' );
    isnt($filename, '',  'Filename is defined');
    isnt(-s $filename, 0, 'temp file is not 0 length');
}

# ripped straight from the pages of RtfExportPlugin.t
sub pdf_for_wikitext {
    my ($wikitext) = @_;
    my $page = $HUB->pages->new_from_name($PAGE_NAME);
    $page->content($wikitext);
    $page->store( user => $HUB->current_user );

    my $pdf_content;
    $HUB->pdf_export->multi_page_export( [$PAGE_NAME], \$pdf_content );

    return $pdf_content;
}

__DATA__
---
- |
    | 1a | 1b |
    | 2a | *2b* |

    hello
- Table and paragraph
---
- '* one'
- Unordered list
---
- |
    .html
    <ul>
    <li>one</li>
    </ul>
    .html
- UL in html block
