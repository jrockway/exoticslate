#!perl
# @COPYRIGHT@

use strict;
use warnings;

use utf8;

use Test::Socialtext tests => 2;
fixtures('db');
use Socialtext::WebApp;
use Socialtext::AppConfig;

Socialtext::AppConfig->set( user_factories => 'Default' );
is( Socialtext::WebApp->username_label(), 'Email Address',
    'default username label is found' );
Socialtext::AppConfig->set( user_factories => 'LDAP:Default' );
is( Socialtext::WebApp->username_label(), 'Username',
    'non-default username label is found' );
