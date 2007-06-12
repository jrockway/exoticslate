#!perl
# @COPYRIGHT@

use strict;
use warnings;

# Does not need any fixtures, but it _does_ need the application
# config file.
use Test::Socialtext tests => 5;

use Socialtext::AppConfig;
use Socialtext::URI;
use File::Path qw/mkpath/;

my $config_file = Test::Socialtext->setup_test_appconfig_dir();
my $appconfig = Socialtext::AppConfig->new(file => $config_file);

# hostnames aren't case-sensitive, so it's safe to lowercase it here
my $hostname = lc $appconfig->web_hostname();

BASIC_TESTS: {
    is( Socialtext::URI::uri( path => '/' ), "http://$hostname/",
        'uri with path of /' );
    is( Socialtext::URI::uri( path => '/', query => { foo => 1 } ),
        "http://$hostname/?foo=1",
        'uri with path of / and foo=1 in query' );
}

NLW_FRONTEND_PORT: {
    local $ENV{NLW_FRONTEND_PORT} = 25000;

    is( Socialtext::URI::uri( path => '/' ), "http://$hostname:25000/",
        'uri with path of / and NLW_FRONTEND_PORT=25000' );
}

Custom_http_port_set: {
    $appconfig->set('custom_http_port', 1234);
    $appconfig->write;
    is $appconfig->custom_http_port, 1234, 'custom port was set';
    is Socialtext::URI::uri( path => '/'), "http://$hostname:1234/",
        'uri with custom http port';
    $appconfig->set('custom_http_port', 0);
    $appconfig->write;
}
