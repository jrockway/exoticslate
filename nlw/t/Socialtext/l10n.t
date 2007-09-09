#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext tests => 12;
use Socialtext::AppConfig;

fixtures('admin_no_pages');

BEGIN {
    use_ok 'Socialtext::l10n', qw(loc loc_lang valid_code system_locale best_locale);
}

set_system_locale('en');
my $hub = new_hub('admin');

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

Test_locale: {
    loc_lang('zz');
    is loc('Welcome, [_1].', 'user'), 'w3lC0M3, user.';
}

Valid_codes: {
    for (qw(en ja zz zj)) {
        ok valid_code($_), "$_ is valid";
    }
}

System_locale: {
    is( system_locale(), 'en', "Checking default system locale." );
    set_system_locale('xx');
    is( system_locale(), 'xx', "Checking changed system locale." );
}

Best_locale: {
    # Force non-english system locale
    set_system_locale('xx');

    #is( best_locale($hub), 'en', "Checking best locale - from user" );
    is( best_locale(), 'xx', "Checking best locale - from system" );
}

sub set_system_locale {
    my $locale = shift;
    Socialtext::AppConfig->set( locale => $locale );
    Socialtext::AppConfig->write;
}
