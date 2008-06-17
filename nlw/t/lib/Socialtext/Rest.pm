package Socialtext::Rest;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::MockBase';
use mocked 'Socialtext::User';

sub user {
    return $_[0]->{user} || Socialtext::User->new,
}

sub header {
    my $self = shift;
    $self->{headers} = { @_ };
}

1;
