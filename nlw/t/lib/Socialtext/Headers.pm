package Socialtext::Headers;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::MockBase';

our $REDIRECT;

sub redirect {
    my $self = shift;
    $REDIRECT = shift;
}

1;
