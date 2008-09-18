# @COPYRIGHT@
package Socialtext::User::Cache;
use strict;
use warnings;
use Socialtext::Cache;

our $Enabled = 0;

sub Fetch {
    my ($class, $factory, $key) = @_;
    return unless $Enabled;
    my $cache = Socialtext::Cache->cache("$factory users");
    return $cache->get($key);
}

sub Store {
    my ($class, $factory, $key, $user) = @_;
    return unless $Enabled;
    my $cache = Socialtext::Cache->cache("$factory users");
    return $cache->set($key, $user);
}

sub Clear {
    my ($class, $factory) = @_;
    return unless $Enabled;
    my $cache = Socialtext::Cache->cache("$factory users");
    return $cache->clear();
}

1;
