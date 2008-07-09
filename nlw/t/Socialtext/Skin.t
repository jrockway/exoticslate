#!perl -w
# @COPYRIGHT@
use strict;
use warnings;
use File::Path qw/mkpath/;
use Socialtext::File qw/set_contents/;
use File::chdir;
use Socialtext::File;

BEGIN {
    use Test::Socialtext tests => 13;
    use_ok( 'Socialtext::Skin' );
    $Socialtext::Skin::CODE_BASE = 't/share';
    $Socialtext::Skin::PROD_VER = '1.0';
}

# Cascading skin
{
    my $hub = new_hub('admin');
    $hub->current_workspace->skin_name('cascades');
    my $info = $hub->skin->css_info;

    is_deeply($info->{standard}, [
        "/static/1.0/skin/s2/css/screen.css",
        "/static/1.0/skin/s2/css/screen.ie.css",
        "/static/1.0/skin/s2/css/print.css",
        "/static/1.0/skin/s2/css/print.ie.css",
        "/static/1.0/skin/cascades/css/screen.css",
        "/static/1.0/skin/cascades/css/screen.ie.css",
        "/static/1.0/skin/cascades/css/print.css",
        "/static/1.0/skin/cascades/css/print.ie.css",
    ], 'Cascading skin containers s2 css');

    is_deeply($info->{common}, [
        "/static/1.0/skin/common/css/common.css",
    ], 'Cascading skin has common.css');

    is_deeply($hub->skin->template_paths, [
        "t/share/skin/s2/template",
        "t/share/skin/cascades/template",
    ], 'Cascading skin has both template dirs');
}

# Non cascading skin
{
    my $hub = new_hub('admin');
    $hub->current_workspace->skin_name('nocascade');
    my $info = $hub->skin->css_info;

    is_deeply($info->{standard}, [
        "/static/1.0/skin/nocascade/css/screen.css",
        "/static/1.0/skin/nocascade/css/screen.ie.css",
        "/static/1.0/skin/nocascade/css/print.css",
        "/static/1.0/skin/nocascade/css/print.ie.css",
    ], 'Non cascading does not include the s2 skin');

    is_deeply($info->{common}, [
        "/static/1.0/skin/common/css/common.css",
    ], 'Non cascading skin has common.css');

    is_deeply($hub->skin->template_paths, [
        "t/share/skin/s2/template",
        "t/share/skin/nocascade/template",
    ], 'Non cascading skin has both template dirs');
}

# S3 skin
{
    my $hub = new_hub('admin');
    $hub->current_workspace->skin_name('s3');
    my $info = $hub->skin->css_info;

    is_deeply($info->{standard}, [
        "/static/1.0/skin/s3/css/screen.css",
    ], 'S3 skin does not include the s2 skin');

    ok(!$info->{common}, "S3 skin does not have common.css");

    is_deeply($hub->skin->template_paths, [
        "t/share/skin/s2/template",
        "t/share/skin/s3/template",
    ], 'S3 skin has both template dirs');
}

# Custom s3 skin
{
    my $hub = new_hub('admin');
    $hub->current_workspace->skin_name('new_s3');
    my $info = $hub->skin->css_info;

    is_deeply($info->{standard}, [
        "/static/1.0/skin/s3/css/screen.css",
        "/static/1.0/skin/new_s3/css/screen.css",
    ], 'Custom s3 skin does not include the s2 skin');

    ok(!$info->{common}, "Custom s3 skin does not have common.css");

    is_deeply($hub->skin->template_paths, [
        "t/share/skin/s2/template",
        "t/share/skin/s3/template",
        "t/share/skin/new_s3/template",
    ], 'Custom s3 skin has both template dirs');
}
