# @COPYRIGHT@
use warnings;
use strict;

=head1 NAME

Socialtext::Search::SimpleAttachmentHit - A basic implementation of Socialtext::Search::AttachmentHit.

=head1 SYNOPSIS

    $hit = Socialtext::Search::SimpleAttachmentHit->new( $page_uri, $attachment_id );

    $hit->page_uri(); # returns $page_uri
    $hit->attachment_id(); # returns $attachment_id

=head1 DESCRIPTION

This implementation simply stores the URI and attachment id in a blessed hash.

=cut

package Socialtext::Search::SimpleAttachmentHit;

use base 'Socialtext::Search::AttachmentHit';

=head1 CONSTRUCTOR

=head2 Socialtext::Search::SimpleAttachmentHit->new( $page_uri, $attachment_id )

Creates an AttachmentHit pointing at the given attachment (attached to the
page with URI $page_uri).

=cut

sub new {
    my ( $class, $page_uri, $attachment_id ) = @_;

    bless { page_uri => $page_uri, attachment_id => $attachment_id }, $class;
}

=head1 OBJECT METHODS

Besides those defined in L<Socialtext::Search::AttachmentHit>, we have

=head2 $hit->set_page_uri($page_uri)

Change the page that this hit points to.

=cut

sub set_page_uri { $_[0]->{page_uri} = $_[1] }

sub page_uri { $_[0]->{page_uri} }

=head2 $hit->set_attachment_id($attachment_id)

Change the attachment that this hit points to.

=cut

sub set_attachment_id { $_[0]->{attachment_id} = $_[1] }

sub attachment_id { $_[0]->{attachment_id} }

=head1 SEE ALSO

L<Socialtext::Search::AttachmentHit> for the interface definition

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
