# @COPYRIGHT@
use warnings;
use strict;

=head1 NAME

Socialtext::ChangeEvent::IndexPage - specialization of 
L<Socialtext::ChangeEvent::Page> for updating indexes.

=head1 SEE

See L<Socialtext::ChangeEvent::Page>.

=cut

package Socialtext::ChangeEvent::IndexPage;

use base 'Socialtext::ChangeEvent::Page';

use Carp 'croak';
use Readonly;

Readonly my $LINK_BASENAME => 'IndexPage-';

sub new {
    my ( $class, $path, $link_path ) = @_;

    ( $link_path =~ qr{$LINK_BASENAME} ) or return '';

    $class->SUPER::new($path, $link_path);
}

sub _link_to { shift->SUPER::_link_to(@_, $LINK_BASENAME); }

1;
