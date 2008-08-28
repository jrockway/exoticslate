#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;

BEGIN { push @INC, 't/plugin/mocked/lib' };

use Test::More tests => 4;
use mocked 'Socialtext::Registry';
use mocked 'Socialtext::Hub';
use Socialtext::Pluggable::Adapter;

my $adapt = Socialtext::Pluggable::Adapter->new;
my $registry = Socialtext::Registry->new;

# use a Mocked hub so that hooks can find their way back to the Adapter
my $hub = Socialtext::Hub->new;
$hub->{pluggable} = $adapt;
$registry->hub($hub);

# Setup hooks before register
Socialtext::Pluggable::Plugin::Mocked->test_hooks(
    'test.name', sub { $_[0]->name },
    'action.test_action' , sub { 'action contents' },
    'wafl.test_wafl', sub { 'wafl contents' },
);

$adapt->register($registry);

ok scalar(grep { /Pluggable::Plugin::Mocked/ } $adapt->plugins),
   'Mocked plugin is loaded';

# Test that name is properly based off the class name
is $adapt->hook('test.name'), 'mocked', 'Mocked name is "mocked"';

is $registry->call('wafl', 'test_wafl'), 'wafl contents',
   "wafl.test_wafl can be called through registry";

is $registry->call('action', 'test_action'), 'action contents',
   "action hooks autovivify and can be called through registry";

