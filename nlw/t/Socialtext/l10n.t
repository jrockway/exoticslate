#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More qw/no_plan/;

BEGIN {
    use_ok 'Socialtext::l10n', qw(loc loc_lang valid_code);
}

Default_to_english: {
    is loc('Welcome, [_1].', 'user'), 'Welcome, user.';
}

French: {
    loc_lang('fr');
    is loc('Welcome, [_1].', 'user'), 'Bienvenue, user.';
}

Spanish: {
    loc_lang('es');
    is loc('Welcome, [_1].', 'user'), 'Bienvenidos, user.';
}

Valid_codes: {
    # everything is valid at this point.  We'll strengthen this up as needed.
    for (qw(en fr jp en_CA)) {
        ok valid_code($_), "$_ is valid";
    }
}
