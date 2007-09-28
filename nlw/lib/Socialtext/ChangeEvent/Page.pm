# @COPYRIGHT@
use warnings;
use strict;

=head1 NAME

Socialtext::ChangeEvent::Page - Representation of a page change.

=cut

package Socialtext::ChangeEvent::Page;

use base 'Socialtext::ChangeEvent';

use Carp 'croak';
use Socialtext::AppConfig;

=head1 CONSTRUCTOR

=head2 Socialtext::ChangeEvent::Page->new($path, $link_path)

If C<$path> is the path to a page, returns a new
L<Socialtext::ChangeEvent::Page> object corresponding to the path.  Otherwise,
returns FALSE.

=cut

sub new {
    my ( $class, $path, $link_path ) = @_;

    my $data_dir = Socialtext::AppConfig->data_root_dir;
    return $path =~ qr{^\Q$data_dir\E/data/(.*?)/(.*)}
        ? bless {
            workspace_name => $1,
            page_uri       => $2,
            link_path      => $link_path,
        }, $class
        : '';
}

=head1 GETTERS

=head2 $event->workspace_name

=head2 $event->page_uri

=head2 $event->link_path

=cut

sub workspace_name { $_[0]->{workspace_name} }
sub page_uri       { $_[0]->{page_uri} }
sub link_path      { $_[0]->{link_path} }

# XXX: not necessary yet, but a step toward getting rid of the 
# "are you my mommy?" logic in S::ChangeEvent.
sub _record_object {
    my $self   = shift;
    my $object = shift;

    $self->_link_to($object->file_path);
}

=head1 SEE ALSO

L<Socialtext::ChangeEvent>, L<Socialtext::Page>

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
