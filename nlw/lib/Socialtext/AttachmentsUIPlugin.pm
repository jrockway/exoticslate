# @COPYRIGHT@
package Socialtext::AttachmentsUIPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use Class::Field qw( const field );
use Socialtext::AppConfig;
use Socialtext::Helpers;
use Socialtext::Exceptions;
use Socialtext::WebApp;

sub class_id { 'attachments_ui' }
const class_title => 'Attachments';
const cgi_class   => 'Socialtext::AttachmentsUI::CGI';
field 'display_limit_value';

const sortdir => {    #default directions
    Subject        => 0,
    From           => 0,
    Content_Length => 0,
    Date           => 1,
    Content_MD5    => 0
};

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add( action => 'listall' );       # XXX "backwards compatibility"
    $registry->add( action => 'attachments' );   # XXX "backwards compatibility"
    $registry->add( action => 'attachments_upload' );
    $registry->add( action => 'attachments_download' );
    $registry->add( action => 'attachments_delete' );
    $registry->add( action => 'attachments_listall' );
}

# backwards compatibility for old links
sub listall {
    my $self = shift;
    $self->redirect('action=attachments_listall');
}

# more backwards comapt
sub attachments {
    my $self = shift;
    $self->redirect(
        '?page_name=' . $self->cgi->page_name . ';js=attachments_div_on' );
}

sub attachments_download {
    my $self = shift;
    my $id      = $self->cgi->id;

    # find filename
    my $attachment = $self->hub->attachments->new_attachment( id => $id );

    eval { $attachment->load };
    return $self->failure_message(
        "Attachment not found. The page name, file name or identifer number "
            . "in the link may be incorrect, or the attachment may have been "
            . "deleted or is not present in this workspace.",
        $@, $self->hub->pages->current

    ) if $@;

    my $file = $attachment->full_path;

    unless ( -e $file ) {

        # TODO: make 404 a real HTTP 404
        die "404: File Not Found: '$file'";
    }
    open my $fh, '<', $file
      or die "Cannot read $file: $!";

    # Add the headers for an attachment
    my $filename = $attachment->filename;
    $self->log_action("DOWNLOAD_ATTACHMENT", $filename);
    $self->hub->headers->add_attachment(
        filename => $filename,
        len      => -s $file,
        type     => $attachment->mime_type
    );

    # Erase Content-Disposition if we want the attachment inline.
    if ( not $attachment->should_popup or $self->cgi->as_page ) {
        $self->hub->headers->content_disposition(undef);
    }

    # Send the data across the wire
    $self->hub->headers->print;
    if ( $ENV{MOD_PERL} ) {
        Apache->request->send_fd($fh);
    }
    else {
        print while <$fh>;
    }

    Socialtext::WebApp::Exception::ContentSent->throw();
}

sub attachments_upload {
    my $self = shift;
    Socialtext::Exception::DataValidation->throw("No file given for upload\n")
        unless defined $self->cgi->file;
    return $self->_finish
        unless $self->hub->checker->check_permission('attachments');

    my $error_code = $self->save_attachment(
        $self->cgi->file,
        $self->cgi->embed,
        $self->cgi->unpack,
    );

    my %args;
    if ($error_code) {
        $error_code =~ s/\. at.*//s;    # grr... stinkin auto-added backtrace.
        $args{attachment_error} = $error_code;
    }

    return $self->_finish(%args);
}

sub save_attachment {
    my $self = shift;
    my $file = shift; # [in] File object/hash from CGI
    my $embed = shift; # [in/optional] boolean - true if link to file should be embedded in page; default to true
    my $unpack = shift; # [in/optional] boolean - true if ZIP file should be unpacked; default to true

    my $filename;
    eval {
        $filename = $file->{filename} . '';
        $self->hub->attachments->from_file_handle(
            fh     => $file->{handle},
            embed  => $embed ? 1 : 0,
            unpack => $unpack ? 1 : 0,

            # this stringification is to remove tied weirdness:
            filename => $filename,
            creator  => $self->hub->current_user,
        );
        $self->log_action("UPLOAD_ATTACHMENT", $filename);
    };

    return $@;
}

sub attachments_listall {
    my $self = shift;

    $self->screen_template('view/attachmentslist');
    $self->render_screen(
        rows =>
            $self->_table_rows( $self->hub->attachments->all_in_workspace() ),
        display_title => "All Files",
    );
}

sub _table_rows {
    my $self        = shift;
    my $attachments = shift;

    my @rows;
    for my $att (@$attachments) {
        my $page = $self->hub->pages->new_page( $att->{page_id} );

        push @rows, {
            link     => $self->_attachment_download_link($att),
            id       => $att->{id},
            filename => $att->{filename},
            user     => $att->{from},
            date     => $self->hub->timezone->date_local( $att->{date} ),
            page     => {
                uri   => $page->uri,
                link  =>
                    Socialtext::Helpers->page_display_link_from_page($page),
            },
            size => $att->{length},
        };
    }

    return \@rows;
}

sub _attachment_download_link {
    my $self = shift;
    my $attachment = shift;

    my $script        = Socialtext::AppConfig->script_name;
    my $filename_uri  = $self->uri_escape( $attachment->{filename} );
    my $filename_html = $self->html_escape( $attachment->{filename} );
    my $page          = $self->hub->pages->new_page( $attachment->{page_id} );
    my $page_uri      = $page->uri;
    my $attachment_id = $attachment->{id};

    return qq|<a href="$script/$filename_uri?action=attachments_download;|
        . qq|page_name=$page_uri;id=$attachment_id">$filename_html</a>|;
}

sub attachments_delete {
    my $self = shift;
    return $self->_finish
        unless $self->hub->checker->check_permission('delete');

    for my $attachment_junk ( $self->cgi->selected ) {
        my ( $page_id, $id, undef ) = map { split ',' } $attachment_junk;
        my $attachment = $self->hub->attachments->new_attachment(
            id      => $id,
            page_id => $page_id,
        );
        $attachment->delete( user => $self->hub->current_user );
    }

    if ( $self->cgi->caller_action eq 'attachments_listall' ) {
        return $self->redirect('action=attachments_listall');
    }

    # If called via AJAX we have nothing to return
    return;
}

sub _finish {
    my $self = shift;
    my %args = @_;

    my $query_string;

    if ( $self->cgi->caller_action eq 'attachments_listall' ) {
        $query_string = 'action=attachments_listall';
    }
    else {
        $query_string = 'action=display;js=toggle_attachments_div;page_name='
            . $self->cgi->page_name;
        $query_string .= ';caller_action=' . $self->cgi->caller_action;
    }

    $query_string .= ";$_=$args{$_}" for keys %args;

    $self->redirect($query_string);
}

#------------------------------------------------------------------------------#
package Socialtext::AttachmentsUI::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'direction';
cgi 'file' => '-upload';  #XXX Looks like the string is already encoded. hmmm???
cgi 'id' => '-clean_path';
cgi 'sortby';
cgi 'redirected';
cgi 'caller_action';
cgi 'button';
cgi 'checkbox';
cgi 'selected';
cgi 'id' => '-clean_path';
cgi 'filename';
cgi 'caller_action';
cgi 'page_name';
cgi 'embed';
cgi 'as_page';
cgi 'unpack';

1;

