#!perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More tests => 2;

BEGIN {
    use_ok 'Socialtext::Schema';
}

Sunny_day: {
    my $s = Socialtext::Schema->new;
    isa_ok $s, 'Socialtext::Schema';
}
