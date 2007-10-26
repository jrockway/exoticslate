#!perl -w
# @COPYRIGHT@
use strict;
use warnings;
use File::Path qw/mkpath/;
use Socialtext::File qw/set_contents/;
use File::chdir;
use Socialtext::File;

my $css_dir = "t/tmp/root/css";

fixtures( 'admin_no_pages' );

BEGIN {
    use Test::Socialtext tests => 5;
    use_ok( 'Socialtext::CSS' );
}


NO_SPECIAL_PATH_FOR_APPLIANCES: {
    my $base_skin = Socialtext::CSS->BaseSkin;
    my $dir = "$css_dir/$base_skin/";
    # The css file needs to exist
    my $css_file = 'print.css';
    mkpath $dir;
    set_contents("$dir/$css_file", 'foo');

    local $ENV{NLW_IS_APPLIANCE} = 1;
    my $hub1 = new_hub('admin');
    my $before = $hub1->css->uris_for_css($css_file);

    $ENV{NLW_IS_APPLIANCE} = 0;
    my $hub2 = new_hub('admin');
    my $after = $hub2->css->uris_for_css($css_file);
    is( length(@$before), length(@$after), "is_appliance has same number of skin folders" );
    for (my $i = 0; $i < length(@$before); $i++) {
        is( $before->[$i], $after->[$i], "$before->[$i] matches $after->[$i]" );
    }
}

IS_STANDARD_FILE_yes: {
    my $hub1 = new_hub('admin');
    my $is_standard = $hub1->css->is_standard_css_file('screen.css');
    is( $is_standard, 1, 'screen.css is a standard CSS file' );
}

IS_STANDARD_FILE_no: {
    my $hub1 = new_hub('admin');
    my $is_standard = $hub1->css->is_standard_css_file('nonstan.css');
    is( $is_standard, 0, 'nonstan.css is not a standard CSS file' );
}

# I can't run this test unless I rewrite it to be a Live test. And there is
# no frickin' way this needs to be a live test. So I am not going to convert
# the test. Things need to change, and this is my first passive aggressive
# attempt to make a change. :-)
#URIS_FOR_NON_DEFAULT_CSS: {
#    my $plugindir = Socialtext::CSS->PluginCssDirectory;
#    my $dir = "$css_dir/$plugindir/";
#    my $css_file = 'plug.css';
#    mkpath $dir;
#    set_contents("$dir/$css_file", 'foo');
#
#    my $hub1 = new_hub('admin');
#    my $plugin_css = $hub1->css->uris_for_non_default_css($dir);
#
#    is( length(@$plugin_css), 1, "There is one plugin CSS file" );
#    ok( $plugin_css->[0] =~ /\/css\/_plugin\/plug.css/, "Plugin CSS name is plug.css" );
#}
