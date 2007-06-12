# @COPYRIGHT@
use warnings;
use strict;

=head1 NAME

Socialtext::ChangeEvent::Attachment - Representation of an attachment change.

=cut

package Socialtext::ChangeEvent::Attachment;

use base 'Socialtext::ChangeEvent';

use Carp 'croak';
use Socialtext::AppConfig;

=head1 CONSTRUCTOR

=head2 Socialtext::ChangeEvent::Attachment->new($path, $link_path)

If C<$path> is the path to an attachment, returns a new
L<Socialtext::ChangeEvent::Attachment> object corresponding to the path.  Otherwise,
returns FALSE.

=cut

sub new {
    my ( $class, $path, $link_path ) = @_;

    my $data_dir = Socialtext::AppConfig->data_root_dir;
    return $path =~ qr{^\Q$data_dir\E/plugin/(.*?)/attachments/(.*?)/(.*?)/}
        ? bless {
            workspace_name => $1,
            page_uri       => $2,
            attachment_id  => $3,
            link_path      => $link_path,
        }, $class
        : '';
}

=head1 GETTERS

=head2 $event->workspace_name

=head2 $event->page_uri

=head2 $event->attachment_id

=head2 $event->link_path

=cut

sub workspace_name { $_[0]->{workspace_name} }
sub page_uri       { $_[0]->{page_uri} }
sub attachment_id  { $_[0]->{attachment_id} }
sub link_path      { $_[0]->{link_path} }

=head1 SEE ALSO

L<Socialtext::ChangeEvent>, L<Socialtext::Attachment>

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
