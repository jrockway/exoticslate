# @COPYRIGHT@
use warnings;
use strict;

=head1 NAME

Socialtext::ChangeEvent::IndexAttachment - specialization of
L<Socialtext::ChangeEvent::Attachment> for updating search indexes.

=head1 SEE

See L<Socialtext::ChangeEvent::Attachment>.

=cut

package Socialtext::ChangeEvent::IndexAttachment;

use base 'Socialtext::ChangeEvent::Attachment';

use Carp 'croak';
use Readonly;

Readonly my $LINK_BASENAME => 'IndexAttachment-';

sub new {
    my ( $class, $path, $link_path ) = @_;

    ( $link_path =~ qr{$LINK_BASENAME} ) or return '';

    $class->SUPER::new($path, $link_path);
}

sub _link_to { shift->SUPER::_link_to(@_, $LINK_BASENAME); }

1;
