package Socialtext::Handler::Attachment;
# @COPYRIGHT@

use strict;
use warnings;

use base 'Socialtext::Handler::Cool';
use Apache::Constants qw(OK);
use YAML;
use JSON;
use Socialtext::TT2::Renderer;
use DateTime;
use DateTime::Format::Strptime;

$JSON::UTF8 = 1;

sub workspace_uri_regex { qr{(?:/lite)?/page/([^/]+)/} }

sub _handle_post {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;

    return $class->_post_attachment($r, $nlw);
}

sub _handle_delete {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;

    my $page = $class->_get_page($r, $nlw);
    return $class->_delete_attachment($r, $nlw, $page);
}

sub _handle_get {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;

    my $page = $class->_get_page($r, $nlw);
    unless ( $class->_user_has_permission( 'read', $nlw->hub ) ) {
        # REVIEW: Probably wrong status to send
        $r->status_line("400 insufficient permission to attach to this page");
        return '', '';
    }

    if ($class->_is_attachment_request($r)) {
        return $class->_get_attachment($r, $nlw, $page);
    } else {
        return $class->_get_listing($r, $nlw, $page);
    }
}

sub _post_attachment {
    my $class = shift;
    my $r = shift;
    my $nlw = shift;

    unless ($class->_is_listing_request($r)) {
        # REVIEW: Probably wrong status to send
        $r->status_line("400 invalid URI for posting attachments");
        return '', '';
    }

    my $page = $class->_get_page($r, $nlw);
    unless ( $class->_user_has_permission( 'attachments', $nlw->hub ) ) {
        # REVIEW: Probably wrong status to send
        $r->status_line("400 insufficient permission to attach to this page");
        return '', '';
    }

    my $content_type = $r->header_in('Content-type');

    if ( defined($page) and $content_type =~ /^multipart\/form-data/ ) {
        return $class->_post_attachment_from_form( $r, $nlw, $page);
    }

    $r->status_line("400 invalid content-type $content_type in post");
    return '', '';
}

sub _delete_attachment {
    my $self = shift;
    my $r = shift;
    my $nlw = shift;
    my $page = shift;

    # We need to report an error message if the attachment does not exist
    my $attachment = $self->_retrieveAttachment($r, $nlw, $page);
    eval { $attachment->load };
    if ($@) {
        $r->status_line("404 $@");
        return '', '';
    }

    $attachment->delete(user => $nlw->hub->current_user);

    return $self->_get_listing($r, $nlw, $page);
}

=head2 _post_attachment_from_form

This method accepts the following parameters from multipart/form-data browser submission:

file - the file to be uploaded, from a <input type="file"> form element

embed - boolean, to embed a link or image directly in the wiki page

unpack - boolean, to unpack zip files and attach each internal file separately

=cut

sub _post_attachment_from_form {
    my ($class, $r, $nlw, $page) = @_;

    my $embed = $r->param('embed');
    my $unpack = $r->param('unpack');

    my $upload = $r->upload; # take one

    if (!defined($upload)) {
        $r->status_line("204 No attachment specified");
        return '', '';
    }

    my ($filename, $handle) = map $upload->$_, qw[filename fh];

    eval {
        $nlw->hub->attachments->from_file_handle(
            fh       => $handle,
            filename => $filename,
            embed    => $embed  ? 1 : 0,
            unpack   => $unpack ? 1 : 0,
            page_id  => $page->id,
            creator  => $nlw->hub->current_user,
        );
    };
    if ($@) {
        $@ =~ s/\. at.*//s;    # grr... stinkin auto-added backtrace.
        $r->status_line("500 $@");
        return '', '';
    }

    $r->content_type('text/plain');
    $r->status_line("201 Ok");

    return $class->_get_listing($r, $nlw, $page);
}


sub _retrieveAttachment {
    my ($class, $r, $nlw, $page) = @_;

    $nlw->hub->pages->current($page);
    my @parts = $r->uri =~ $class->_uri_parts_regex;
    my $id      = $parts[2];
    my $page_id = $page->id;

    # collapse multiple dots or slashes to one (no going up out of files dir)
    $page_id =~ s/\.+/./g;
    $page_id =~ s#/+#/#g;

    my $attachment = $nlw->hub->attachments->new_attachment( id => $id );

    return $attachment;
}


sub _get_attachment {
    my ($class, $r, $nlw, $page) = @_;

    my $attachment = $class->_retrieveAttachment($r, $nlw, $page);

    eval { $attachment->load };
    if ($@) {
        $r->status_line("404 $@");
        return '', '';
    }

    my $file = $attachment->full_path;

    unless ( -e $file ) {

        $r->status_line("404 File Not Found: '$file'");
        return '', '';
    }
    my $fh;
    unless (open $fh, '<', $file) {
        $r->status_line("404 Cannot read: '$file'");
        return '', '';
    }

    $r->content_type( $attachment->mime_type );
    $r->header_out('Content-length' => -s $file );
    $r->header_out('Content-disposition' => 'inline; filename="' . $attachment->filename . '"');
    # Normally, we'd want to turn off caching, but see
    # http://support.microsoft.com/default.aspx?scid=kb;en-us;812935
    # for why we don't - gotta love IE.

    $r->send_http_header();
    $r->send_fd($fh);
    close($fh);

    return OK;
}

sub _get_listing {
    my ($class, $r, $nlw, $page) = @_;
    my $accept = $r->header_in('Accept');

    my $c = 0;
    my @attachments =    map {{
            filename    => $_->filename,
            id          => $_->id,
            upload_date => $class->_date_only($_->Date),
            upload_time => $class->_time_only($_->Date),
            date        => $class->_date_epoch_from($_->Date),
            from        => $_->From,
            filesize    => $_->Content_Length,
            mime_type   => $_->mime_type,
        }}
    sort { lc($a->filename) cmp lc($b->filename) }
    @{$nlw->hub->attachments->all( page_id => $page->id ) };

    if (defined($accept) && (($accept =~ m[\btext/javascript\b]) || ($accept =~ m[\*/\*]))) {
        return $class->_get_listing_json(\@attachments);
    } elsif (defined($accept) && ($accept =~ m[\btext/html\b])) {
        return $class->_get_listing_xhtml($r, \@attachments);
    } else {
        return $class->_get_listing_json(\@attachments);
    }
}

sub _get_listing_xhtml {
    my $class = shift;
    my $r = shift;
    my $attachments = shift;

    my @parts = $r->uri =~ $class->_uri_parts_regex;
    my $renderer = Socialtext::TT2::Renderer->instance;
    my $xhtml = $renderer->render(
        template => 'handler/attachment/listing-xhtml',
        vars     => {
            attachments => $attachments,
            workspace => $parts[0],
            page => $parts[1],
        },
    );
    return $xhtml, 'text/html';
}

sub _get_listing_json {
    my ($class, $attachments) = @_;
    return JSON::objToJson({attachments => $attachments}), 'text/html'; # I hate doing this, but Safari...
}

sub _get_listing_text {
    my ($class, $attachments) = @_;
    return YAML::Dump($attachments), 'text/plain';
}

sub _date_epoch_from {
    my ($class, $date) = @_;
    my $strptime = DateTime::Format::Strptime->new(
        pattern => '%F %T %Z',
    );
    return $strptime->parse_datetime($date)->epoch;
}

sub _date_only {
    my ($class, $date) = @_;
    my $strptime = DateTime::Format::Strptime->new(
        pattern => '%F %T %Z',
    );
    return $strptime->parse_datetime($date)->ymd;
}

sub _time_only {
    my ($class, $date) = @_;
    my $strptime = DateTime::Format::Strptime->new(
        pattern => '%F %T %Z',
    );
    return $strptime->parse_datetime($date)->hms;
}

sub _get_page {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;

    # REVIEW: This regexp may need some thought
    my ($page_id) = ( $r->uri =~ m{/page/[^\/]+/([^?/]+)\??.*$} );
    # REVIEW: The hub+current makes the baby jesus cry
    $page_id ||= $nlw->hub->current_workspace->title;
    if ($page_id) {
        # This little game is to avoid weirdnesses in page->title
        my $id = $nlw->uri_unescape($page_id);
        my $page = Socialtext::Page->new(
            hub => $nlw->hub,
            id  => Socialtext::Page->name_to_id($id),
        );
        my $return_id = Socialtext::Page->name_to_id($page->title);

        $page->title( $id )
            unless $return_id eq $page_id;
        return $page;
    }
    return undef;
}

sub _is_attachment_request {
    my ($class, $r) = @_;
    my @parts = $r->uri =~ $class->_uri_parts_regex;
    return defined $parts[2];
}

sub _is_listing_request {
    my ($class, $r) = @_;
    my @parts = $r->uri =~ $class->_uri_parts_regex;
    return ! defined $parts[2];
}

sub _get_attachment_id {
    my ($class, $r) = @_;
    my @parts = $r->uri =~ $class->_uri_parts_regex;
    return $parts[2];
}

=head2 _uri_parts_regex

Given a URI for requesting a particular attachment:

  my ($workspace_id, $page_id, $attachment_id)
    = $r->uri =~ $class->_uri_parts_regex;

Given a URI for requesting the attachments list, or posting an attachment to the pool:

  my ($workspace_id, $page_id)
    = $r->uri =~ $class->_uri_parts_regex;

=cut

sub _uri_parts_regex {
    # Example: /page/corp/baseball/attachments
    #          /page/corp/baseball/attachments/20060621154226-0-324
    qr|
        /page/
        ([^/]+)      # workspace id
        /
        ([^/]+)      # page id
        /
        attachments
        (?:
            /
            (
                \d{14} # attachment id: timestamp
                (?:-
                \d+)?    # attachment id: number (optional)
                (?:-
                \d+)?    # attachment id: uniquifier (optional)
            )
        )?
    |x
}

1;

__END__

=head1 NAME

Socialtext::Handler::Attachment - A Cool URI Interface to NLW Page Attachments

=head1 SYNOPSIS

    PerlModule  Socialtext::Handler::Attachment
    <Location /page/*/*/attachments>
        SetHandler  perl-script
        PerlHandler Socialtext::Handler::Attachment
    </Location>

=head1 DESCRIPTION

B<Socialtext::Handler::Attachment> is an interface to NLW's page attachments feature using more traditional URIs, and taking advantage of the HTTP protocol in a RESTful way.

=head1 URIs

The URI for an attachment is
C</page/workspace/page_id/attachments/attachment_id>. You can C<GET>
attachments from that URI. The URI for listing attachments on a page is
C</page/workspace/page_id/attachments>. You can C<GET> a list of information
about attachments on the page in JSON serialized format by specifying that you
Accept C<text/json> in the request header. To C<POST> an attachment, send it
to C</page/workspace/page_id/attachments> using a form with the encoding type
of C<multipart/form-data>.

=head1 SEE ALSO

L<Socialtext::Handler::Cool>, L<Socialtext::Handler::Page>

=cut
