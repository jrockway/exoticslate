#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::More;

my @plugins = grep { !m{/(?:Default|CSSKit)\.pm$} }
              glob("lib/Socialtext/Pluggable/Plugin/*.pm");

plan tests => scalar @plugins;

for my $plugin (@plugins) {
    my ($name) = $plugin =~ m{/([^/]+)\.pm$};
    my $ok = 1;
    open my $fh, $plugin or die "Can't open $plugin: $!";
    while (<$fh>) {
        if (m{(\S*->hub\S*)}) {
            $ok = 0;
            diag "$name plugin uses the hub directly: $1";
        }
    }
    ok $ok, $plugin;
    close $fh;
}
