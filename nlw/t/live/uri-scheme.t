#!perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Live fixtures => [qw(admin)];
use Test::More tests => 4;
use Socialtext::Hostname;
use Socialtext::HTTPPorts qw(SSL_PORT_DIFFERENCE);

# borrowed from wsdl-0.9.t

my $live     = Test::Live->new();
my $base_uri = $live->base_url;
my $feed     = $base_uri . '/feed/workspace/admin?page=what_if_i_make_a_mistake';
my $host     = Socialtext::Hostname::fqdn();
my $port     = $< + 30000;
my $ssl_port = $port + SSL_PORT_DIFFERENCE;

$live->mech( WWW::Mechanize->new() );

$live->log_in();

{
    $live->mech->get($feed);
    is( $live->mech->status, 200, "GET $feed gives 200" );
    my $content = $live->mech->content;

    like $content,
        qr{img alt="http://[^/]+/admin/base/images/docs/View-Page-Revisions.png" src="http://[^/]+/admin/base/images/docs/View-Page-Revisions.png"},
        'url for image is http';
}

{
    $feed =~ s/http/https/;
    $feed =~ s/$port/$ssl_port/;
    $live->mech->get($feed);
    is( $live->mech->status, 200, "GET $feed gives 200" );
    my $content = $live->mech->content;
    like $content,
        qr{img alt="https://[^/]+/admin/base/images/docs/View-Page-Revisions.png" src="https://[^/]+/admin/base/images/docs/View-Page-Revisions.png"},
        'url for image is https';
}
