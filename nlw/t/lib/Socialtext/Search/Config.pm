package Socialtext::Search::Config;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::MockBase';

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub search_box_snippet {
    return '<div><form></form></div>';
}

1;
