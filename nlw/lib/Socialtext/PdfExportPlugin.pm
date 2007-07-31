# @COPYRIGHT@
package Socialtext::PdfExportPlugin;
use warnings;
use strict;
use base 'Socialtext::Plugin';

use Socialtext::PdfExport::LinkDictionary;
use File::chdir;
use Socialtext::l10n qw(loc);
use IPC::Run 'run';
use Readonly;
use Class::Field 'const';

=head1 NAME

Socialtext::PdfExportPlugin - Export a Workspace Page to PDF

=head1 DESCRIPTION

This module provides a system for outputting a PDF version of
a workspace page or pages that the user may save. The system
works by creating an HTML version of the pages and then
translating that version to PDF.

The translation is performed by calling the external command
C<htmldoc>.

=head1 METHODS

=cut

sub class_id {'pdf_export'};
const class_title => 'PDF Export';
const cgi_class   => 'Socialtext::PdfExportPlugin::CGI';

Readonly my @COMMAND => qw(
    htmldoc -t pdf
    --verbose --footer '' --header ''
    --path / --textfont helvetica --bodyfont helvetica --headingfont helvetica
    --no-strict --no-title --no-toc --no-compression --webpage
);

sub register {
    my $self     = shift;
    my $registry = shift;

    $registry->add( action => 'pdf_export' );
}

=head2 pdf_export

An action callable by the web interface to return a PDF
version of the page or pages named in the CGI page variable
C<page_selected>.

=cut
sub pdf_export {
    my $self = shift;

    my @page_names = $self->cgi->page_selected;
    if (0 == @page_names) {
        return loc("Error:<pre>No pages selected for export</pre>\n");
    }

    my $pdf_content;

    if ($self->multi_page_export(\@page_names, \$pdf_content)) {
        my $filename = $self->cgi->filename || "$page_names[0].pdf";
        $self->hub->headers->add_attachment(
            filename => $filename,
            len      => length($pdf_content),
            type     => 'application/pdf',
        );
        return $pdf_content;
    }
    return "Error:<pre>$pdf_content</pre>\n";
}

=head2 multi_page_export($page_names, \$output)

Puts a PDF representation of the the pages names in C<$page_names> into C<$output>. The
pages are placed on new pages. This method returns TRUE if the creation of the PDF file
was successul. If there was an error, an error message is placed in C<$output> and
C<multi_page_export> returns FALSE.

=cut
sub multi_page_export {
    my $self       = shift;
    my $page_names = shift;
    my $out_ref    = shift;

    return _run_htmldoc(
        '', $out_ref, @COMMAND,
        map { $self->_create_html_file($_) } @$page_names
    );
}


# _run_htmldoc( $input, $output_ref, @command )
#
# Runs the htmldoc command @command using the given input and output ref.
# Returns TRUE if a valid PDF file is created and false otherwise.
sub _run_htmldoc {
    my ( $input, $output_ref, @command ) = @_;

    my $err;
    # We ignore the exit code because htmldoc sometimes exits nonzero even
    # when a PDF was created.  We check for the '%PDF' magic number at the top
    # of the output instead. -mml
    {
        local $ENV{HTMLDOC_NOCGI} = 1;
        local $ENV{HTMLDOC_DEBUG} = 'all';

        # We must set our working directory to '/' because (and this is
        # undocumented, AFAICT; I got it from the source) if htmldoc reads
        # from STDIN, it forcibly sets '.' (the current working directory) to
        # be the root where it begins looking for files. -mml
        local $CWD = '/';

        # Sometimes htmldoc has errors trying to write to a tmp file
        # that is already there. That corresponds to a 512 or 1024 
        # return from the run command. This is a hack making up 
        # for lameness in htmldoc. It runs the same command again
        # if a first attempt doesn't work. This doesn't happen
        # very often.
        my $attempts = 0;
        while ($attempts < 5) {
            run \@command, \$input, $output_ref, \$err;
            my $wait_result = $?;
            last unless ($wait_result == 512 || $wait_result == 1024 );
            $attempts++;
        }
    }

    return '%PDF' eq substr $$output_ref, 0, 4;
}

# EXTRACT: This probably belongs as a special method on either the formatter
# or the page.
sub _get_html {
    my $self = shift;
    my $page_name = shift;
    my $page = $self->hub->pages->new_from_name( $page_name );

    no warnings 'once', 'redefine';

    # Hack in table borders, HTML 3.2 style.
    local *Socialtext::Formatter::Table::html_start = sub {
        qq{<table
                border="1"
                cellpadding="3"
                style="border-collapse: collapse;"
                class="formatter_table">\n}
    };

    # Old school here.  htmldoc doesn't support the &trade; entitity, and it
    # doesn't support Unicode.
    local *Socialtext::Formatter::TradeMark::html = sub {'<SUP>TM</SUP>'};

    # FIXME: Add special link dictionary here.
    return "<html><head><title>"
        . $page->metadata->Subject
        . "</title><body>"
        . $page->to_absolute_html(
            undef,
            link_dictionary => Socialtext::PdfExport::LinkDictionary->new )
        . "</body></html>";
}


sub _create_html_file {
    my $self = shift;
    my $page_name = shift;

    my $html = $self->_get_html($page_name);
    my $temp_file = File::Temp->new(UNLINK => 0, DIR => '/tmp', SUFFIX => '.html');
    print $temp_file $html;
    return $temp_file->filename;
}

package Socialtext::PdfExportPlugin::CGI;
use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'page_selected';
cgi 'filename';


1;

=head1 AUTHOR

Socialtext, C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2005 Socialtext, Inc. All Rights Reserved.

=cut
