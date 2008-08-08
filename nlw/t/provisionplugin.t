#!perl
# @COPYRIGHT@

# this test validates that the correct workspace customization attributes
# are "inherited" by newly created workspaces via the web UI
# 
use strict;
use warnings;

use Test::More tests => 2;
use Test::Socialtext;
fixtures( 'admin' );


BEGIN {
    use_ok( "Socialtext::ProvisionPlugin" );
}

{
    $ENV{GATEWAY_INTERFACE} = 1;
    $ENV{QUERY_STRING} = '';
    $ENV{REQUEST_METHOD} = 'GET';
    my $admin_hub = new_hub('admin');

    my $workspaces_plugin = $admin_hub->provision_ui;

    ok( $workspaces_plugin, "can't even create plugin" );
}
