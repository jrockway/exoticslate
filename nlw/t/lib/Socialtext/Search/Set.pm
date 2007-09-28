package Socialtext::Search::Set;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::MockBase';

sub AllForUser {
    my $class = shift;
    return bless {}, $class;
}

sub all {
    return qw( one two three );
}

1;
