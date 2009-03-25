# @COPYRIGHT@
package Socialtext::AccountInvitation;

use strict;
use warnings;

our $VERSION = '0.01';

=pod

=over 4

=item * account => $account

=item * from_user => $from_user

=item * invitee   => $invitee_address

=item * extra_text => $extra_text

=item * viewer    => $viewer

=back

=cut

sub new {
    my $class = shift;
    my $self = { @_ };
    bless $self, $class;
    return $self;
}

sub send {
    my $self = shift;

    # XXX TODO XXX
    return;
}


1;
