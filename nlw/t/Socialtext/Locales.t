#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More tests => 8;
use utf8;

BEGIN {
    use_ok 'Socialtext::Locales', qw(valid_code available_locales);
}

Valid_codes: {
    for (qw(en ja zz zj)) {
        ok valid_code($_), "$_ is valid";
    }
}

Available_locales: {
    my $locales = available_locales();
    isa_ok $locales, 'HASH';
    is $locales->{en}, 'English', 'en locale works';
    is $locales->{ja}, 'Japanese (日本語)', 'ja locale works';
}
