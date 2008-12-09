#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;

BEGIN { push @INC, 't/share/plugin/fakeplugin/lib' };

use Test::More tests => 7;
use mocked 'Socialtext::Registry';
use mocked 'Socialtext::Hub';
use Socialtext::Pluggable::Adapter;

my $adapt = Socialtext::Pluggable::Adapter->new;
my $registry = Socialtext::Registry->new;

# use a Mocked hub so that hooks can find their way back to the Adapter
my $hub = Socialtext::Hub->new;
$hub->{pluggable} = $adapt;
$adapt->{hub} = $hub;
$registry->hub($hub);

{ # force plugins to always be enabled
    no warnings 'redefine';
    *Socialtext::Account::is_plugin_enabled = sub {1};
}

# Setup hooks before register
Socialtext::Pluggable::Plugin::FakePlugin->test_hooks(
    'test.name', sub { $_[0]->name },
    'action.test_action' , sub { 'action contents' },
    'wafl.test_wafl', sub { 'wafl contents' },
);

$adapt->register($registry);

ok scalar(grep { /Pluggable::Plugin::FakePlugin/ } $adapt->plugins),
   'Mocked plugin is loaded';

ok scalar(grep { $_ eq 'fakeplugin' } $adapt->plugin_list),
   'Mocked plugin shows up in plugin_list';

ok $adapt->plugin_exists('fakeplugin'), 'plugin_exists returns true when the plugin exists';
ok !$adapt->plugin_exists('something'), 'plugin_exists returns false when the plugin does not exist';

# Test that name is properly based off the class name
is $adapt->hook('test.name'), 'fakeplugin', 'FakePlugin name is "fakeplugin"';

is $registry->call('wafl', 'test_wafl'), 'wafl contents',
   "wafl.test_wafl can be called through registry";

is $registry->call('action', 'test_action'), 'action contents',
   "action hooks autovivify and can be called through registry";

