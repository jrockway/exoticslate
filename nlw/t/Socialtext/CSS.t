#!perl -w
# @COPYRIGHT@
use strict;
use warnings;
use File::Path qw/mkpath/;
use Socialtext::File qw/set_contents/;

use Test::Socialtext tests => 2;
fixtures( 'admin_no_pages' );

BEGIN {
    use_ok( 'Socialtext::CSS' );
}


NO_SPECIAL_PATH_FOR_APPLIANCES: {
    # The css file needs to exist
    my $css_dir = "t/tmp/root/css/st/";
    my $css_file = 'print.css';
    mkpath $css_dir;
    set_contents("$css_dir/$css_file", 'foo');

    local $ENV{NLW_IS_APPLIANCE} = 1;
    my $hub1 = new_hub('admin');
    my $before = $hub1->css->uri_for_css($css_file);

    $ENV{NLW_IS_APPLIANCE} = 0;
    my $hub2 = new_hub('admin');
    my $after = $hub2->css->uri_for_css($css_file);
    is( $before, $after, "is_appliance does not affect CSS paths" );
}
