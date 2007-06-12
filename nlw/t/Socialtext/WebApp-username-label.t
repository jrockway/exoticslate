#!perl
# @COPYRIGHT@

use strict;
use warnings;

use utf8;

BEGIN {
    # This is needed to fake out HTML::Mason::ApacheHandler to just
    # load outside mod_perl
    sub Apache::perl_hook { 1 }
    sub Apache::server { 0 }
}

use Test::Socialtext tests => 2;
fixtures( 'admin_no_pages' );
use Socialtext::WebApp;
use Socialtext::AppConfig;

is( Socialtext::WebApp->username_label(), 'Email Address',
    'default username label is found' );
Socialtext::AppConfig->set( user_factories => 'LDAP:Default' );
is( Socialtext::WebApp->username_label(), 'Username',
    'non-default username label is found' );
