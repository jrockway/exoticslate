#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext tests => 7;
use Socialtext::AppConfig;

fixtures('admin_no_pages');

BEGIN {
    use_ok 'Socialtext::l10n', qw(loc loc_lang best_locale system_locale);
}

set_system_locale('en');
my $hub = new_hub('admin');

Default_to_english: {
    is loc('Welcome, [_1].', 'user'), 'Welcome, user.';
}

Test_locale: {
    loc_lang('zz');
    is loc('Welcome, [_1].', 'user'), 'w3lC0M3, user.';
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
exit;

AutoBlockQuoting: {
    is(
        loc(
            'Foo [_2] ~[cow love] [quant,_4,foo,foos] [_1] [*,_4,blah][food][sofa]~~~~~[lick]~[love dude][_3]~[squared]man ~~~~~~[eek] [_1]',
            "aaa", "bbb", "ccc", 15
        ),
        "Foo bbb [cow love] 15 foos aaa 15 blahs[food][sofa]~~[lick][love dude]ccc[squared]man ~~~[eek] aaa",
        "Ensure that non-variable square brackets are quoted away."
    );
}

sub set_system_locale {
    my $locale = shift;
    Socialtext::AppConfig->set( locale => $locale );
    Socialtext::AppConfig->write;
}
