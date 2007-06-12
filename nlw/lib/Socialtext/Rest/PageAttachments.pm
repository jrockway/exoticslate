package Socialtext::Rest::PageAttachments;
# @COPYRIGHT@

use warnings;
use strict;

use base 'Socialtext::Rest::Attachments';

use Fcntl ':seek';
use File::Temp 'tempfile';
use Socialtext::HTTP ':codes';

=head2 POST

Create a new attachment.  The name must be passed in using the C<name> CGI
parameter.  server. If creation is successful, return 201 and the Location: of
the new page

=cut

sub POST {
    my ( $self, $rest ) = @_;

    return $self->no_workspace() unless $self->workspace;
    return $self->not_authorized() unless $self->user_can('attachments');

    # TODO: We presumably should do some kind magic header
    # checking, but in the meantime, rather than doing a 500
    # when we are unable to provide a content-type, return a 409
    # explaining the need for a content-type header.
    my $content_type = $rest->request->header_in('Content-Type');
    unless ($content_type) {
        $rest->header(
            -status => HTTP_409_Conflict,
            -type   => 'text/plain',
        );
        return 'Content-type header required';
    }

    my $content_fh = tempfile;
    $content_fh->print($rest->getContent);
    seek $content_fh, 0, SEEK_SET;

    my $name    = Apache::Request->new(Apache->request)->param('name')
        or return $self->_http_401(
            'You must supply a value for the "name" parameter.' );

    # TODO Content-type handling here and in Socialtext::Attachment.
    my $attachment = $self->hub->attachments->from_file_handle(
        fh           => $content_fh,
        embed        => 0,
        'unpack'     => 0,
        filename     => $name,
        Content_type => $content_type,
        creator      => $rest->user,
        page_id      => $self->page->id, );

    # REVIEW: We should be able to call "$self->parent_url(2)" or whatever and
    # get the URL 2 levels above us.  $self->parent_url(0) would return our
    # own URL (sans query params).  EXTRACT that to Socialtext::Rest.

    my $base = $self->rest->query->url( -base => 1 );
    $rest->header(
        -status   => HTTP_201_Created,
        -Location => "$base/data/workspaces/"
            . $self->ws
            . "/attachments/"
            . $self->page->uri . ':'
            . $attachment->id
            . '/files/'
            . $attachment->filename
    );
    return '';
}

sub allowed_methods { 'GET, HEAD, POST' }

sub _entities_for_query {
    my $self = shift;
    return @{ $self->hub->attachments->all( page_id => $self->page->id ) };
}

1;

