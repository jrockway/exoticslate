package Socialtext::Rest::Attachment;
# @COPYRIGHT@

use warnings;
use strict;

use base 'Socialtext::Rest';
use IO::File;
use Socialtext::HTTP ':codes';
use Socialtext::l10n qw(system_locale);

sub allowed_methods { 'GET, HEAD, DELETE' }
sub permission { +{ GET => 'read', DELETE => 'attachments' } }

# REVIEW we should consider using
#    my $file = $attachment->full_path;
#    open my $fh, $file
#    $self->request->send_fd($fh);
# if we can skirt the header and content sending being done elsewhere
sub GET {
    my ( $self, $rest ) = @_;

    return $self->no_workspace() unless $self->workspace;
    return $self->not_authorized() unless $self->user_can('read');

    my $fh;
    eval {
        my $attachment = $self->_get_attachment();
        my $file = $attachment->full_path( $self->params->{version} );

        unless ( -e $file ) {
            $self->_invalid_attachment( $rest, 'not found' );
        }

        my $mime_type = $attachment->mime_type;

        if ( $mime_type =~ /^text/ ) {
            my $charset = $attachment->charset(system_locale());
            if (! defined $charset) {
                $charset = 'UTF8';
            }
            $mime_type .= '; charset=' . $charset;
        }

        $fh = new IO::File $file, 'r';
        die "Cannot read $file: $!" unless $fh;

        # See Socialtext::Headers::add_attachments for the IE6/7 motivation
        # behind Pragma and Cache-control below.
        $rest->header(
            '-content-length' => -s $file,
            -type             => $mime_type,
            -pragma           => undef,
            '-cache-control'  => undef,
            'Content-Disposition' => 'filename="' . $attachment->filename . '"',
        );
    };
    # REVIEW: would be nice to be able to toss some kind of exception
    # all the way out to the browser
    # Probably an invalid attachment id.
    return $self->_invalid_attachment( $rest, $@ ) if $@;
    return $fh;
}

sub DELETE {
    my ( $self, $rest ) = @_;

    return $self->no_workspace() unless $self->workspace;

    $self->if_authorized(
        DELETE => sub {
            my $attachment = eval { $self->_get_attachment(); };
            return $self->_invalid_attachment( $rest, $@ ) if $@;

            $attachment->delete( user => $rest->user );
            $rest->header( -status => HTTP_204_No_Content );
            return '';
        }
    );
}

sub _invalid_attachment {
    my ( $self, $rest, $error ) = @_;

    $rest->header( -status => HTTP_404_Not_Found, -type => 'text/plain' );
    return "Invalid attachment ID: $error.\n";
}

sub _get_attachment {
    my $self = shift;
    my ( $page_uri, $attachment_id ) = split /:/, $self->attachment_id;

    my $page_id =  Socialtext::Page->name_to_id($page_uri);

    my $attachment = $self->hub->attachments->new_attachment(
        id      => $attachment_id,
        page_id => $page_id,
    )->load;

    return $attachment;
}



1;
