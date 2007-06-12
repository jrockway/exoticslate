#!perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::More;

use Socialtext::Hostname ();
use Sys::Hostname ();

# The only way to test if this thing is working is when it's run on a
# system where we know what results to expect. On a system that's
# misconfigured we can easily get entirely bogus results.
my %KnownHosts = (
    'houseabsolute.urth.org' => {
        hostname => 'houseabsolute',
        domain   => 'urth.org',
        fqdn     => 'houseabsolute.urth.org',
    },
    'talc.socialtext.net' => {
        hostname => 'talc',
        domain   => 'socialtext.net',
        fqdn     => 'talc.socialtext.net',
    },
);

my $hn = Sys::Hostname::hostname();
my $expect = $KnownHosts{$hn};
if ($expect) {
    plan tests => 3;
}
else {
    plan skip_all => "Cannot run these tests on a host we don't know about ($hn)";
}

is( Socialtext::Hostname::hostname(), $expect->{hostname},
    'check hostname()' );
is( Socialtext::Hostname::domain(), $expect->{domain},
    'check domain()' );
is( Socialtext::Hostname::fqdn(), $expect->{fqdn},
    'check fqdn()' );
