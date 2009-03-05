package Socialtext::Rest::User;
# @COPYRIGHT@

use warnings;
use strict;

use base 'Socialtext::Rest::Entity';

use Socialtext::Functional 'hgrep';
use Socialtext::User;

# FIXME: Attention paid to permissions is incomplete.

our $k;

# We punt to the permission handling stuff below.
sub permission { +{ GET => undef } }
sub entity_name { "User " . $_[0]->username }

sub get_resource {
    my ( $self, $rest ) = @_;

    my $acting_user = $self->rest->user;
    my $user = Socialtext::User->new( username => $self->username );

    # REVIEW: A permissions issue at this stage will result in a 404
    # which might not be the desired result. In a way it's kind of good,
    # in an information hiding sort of way, but....
    if (
        $user
        && (   $acting_user->is_business_admin()
            || $user->username eq $acting_user->username )
        ) {
        return +{
            ( hgrep { $k ne 'password' } %{ $user->to_hash } ),
            accounts => [ map { $_->hash_representation } $user->accounts ],
        };
    }
    return undef;
}

1;
