#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::More qw(no_plan);
use Socialtext::User;
use Socialtext::Account;
use Socialtext::Workspace;
use Socialtext::AppConfig;
use_ok 'Socialtext::Pluggable::Plugin';
use_ok 'Socialtext::Pluggable::Adapter';

my $adapter = Socialtext::Pluggable::Adapter->new;
my $plug = Socialtext::Pluggable::Plugin->new;
my $ws = Socialtext::Workspace->new( name => 'admin' );
$plug->hub($adapter->make_hub(Socialtext::User->SystemUser, $ws));

is $plug->uri, 'http://topaz.socialtext.net:32018/admin/index.cgi', 'uri';
is $plug->code_base, Socialtext::AppConfig->code_base, 'code_base';

