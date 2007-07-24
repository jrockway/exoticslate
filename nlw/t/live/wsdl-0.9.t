#!perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Live fixtures => [qw(admin)];
use Test::More tests => 4;
use Socialtext::Hostname;
use Socialtext::HTTPPorts qw(SSL_PORT_DIFFERENCE);

my $live     = Test::Live->new();
my $base_uri = $live->base_url;
my $wsdl     = $base_uri . '/static/wsdl/0.9.wsdl';
my $host     = Socialtext::Hostname::fqdn();
my $port     = $< + 30000;
my $ssl_port = $port + SSL_PORT_DIFFERENCE;

=for future fixes XXX

This test needs to check that we get back a real 200 OK from the server.
RT ticket #23921 found that no content-type or 200 OK was getting sent
back when requesting the WSDL file.  Since we always test through a proxy,
this is a non-issue, because the proxy just supplies its own 200.

To test this, you'll have to check the $response->{_msg} field directly,
and not just check $response->code, because we already know it comes
back as 200.  What we want is to check that the _msg is "200 OK" not
"200 Assumed OK".

To update this test properly, we need to update the infrastructure to
allow the test to query Socialtext::Build as to what ports the various
Apaches are running on: APP_HTTP_PORT, APP_HTTPS_PORT, PROXY_HTTP_PORT
and PROXY_HTTPS_PORT, most likely.  Then, this test can query directly
on the APP_HTTP_PORT and be sure of bypassing the proxy.

Finally, we have to make sure that dev-bin/fresh-dev-env-from-scratch
properly respects --apache-proxy=0 and --apache-proxy=1 so that we can
have those parms set in a configset and the testrunner can test that we
work both behind the proxy and not.

=cut


$live->mech( WWW::Mechanize->new() );

# FIXME: wsdl file is not supposed to require log in
# this test will pass if the below is unchecked.
#$live->log_in();

{
    $live->mech->get($wsdl);
    is($live->mech->status, 200, "GET $wsdl gives 200");
    like( $live->mech->content, qr/$host:$port/,
        "Check for $host:$port in WSDL" );
}

{
    $wsdl =~ s/http/https/;
    $wsdl =~ s/$port/$ssl_port/;
    $live->mech->get($wsdl);
    is($live->mech->status, 200, "GET $wsdl gives 200");
    like( $live->mech->content, qr/$host:$ssl_port/,
        "Check for $host:$ssl_port in WSDL" );
}
