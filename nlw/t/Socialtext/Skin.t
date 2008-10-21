#!perl -w
# @COPYRIGHT@
use strict;
use warnings;
use File::Path qw/mkpath/;
use Socialtext::File qw/set_contents/;
use File::chdir;
use Socialtext::File;

BEGIN {
    use Test::Socialtext tests => 23;
    use_ok( 'Socialtext::Skin' );
    $Socialtext::Skin::CODE_BASE = 't/share';
    $Socialtext::Skin::PROD_VER = '1.0';
    fixtures( 'admin' );
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

# Uploaded skin
{
    my $hub = new_hub('admin');
    $hub->current_workspace->skin_name('s2');
    $hub->current_workspace->uploaded_skin('1');

    my $info = $hub->skin->css_info;

    is_deeply($info->{standard}, [
        "/static/1.0/skin/s2/css/screen.css",
        "/static/1.0/skin/s2/css/screen.ie.css",
        "/static/1.0/skin/s2/css/print.css",
        "/static/1.0/skin/s2/css/print.ie.css",

        "/static/1.0/uploaded-skin/admin/css/screen.css",
    ], 'Uploaded skin css is included');

    is_deeply($hub->skin->template_paths, [
        "t/share/skin/s2/template",
        "t/share/uploaded-skin/admin/template",
    ], 'Uploaded templates are included in template_paths');
}

# Socialtext::Skin works outside the hub
{
    my $cascades = Socialtext::Skin->new(name => 'cascades');
    is $cascades->skin_info->{parent}, 's2', 'cascades inherits from s2';
    is $cascades->parent->skin_info->{skin_name}, 's2', 'parent is s2';
    is $cascades->skin_info->{cascade_css}, 1, 'cascades cascades';
    is_deeply($cascades->template_paths, [
        "t/share/skin/s2/template",
        "t/share/skin/cascades/template",
    ], 'Cascading skin has both template dirs');
}

# Non existent skins return undef
{
    my $skin = Socialtext::Skin->new(name => 'absent');
    isa_ok $skin, 'Socialtext::Skin', 'got the "absent" skin';
    ok !$skin->exists, "... and it doesn't actually exist";
}

# make_dirs
{
    my @s2 = Socialtext::Skin->new(name => 's2')->make_dirs;
    my @s3 = Socialtext::Skin->new(name => 's3')->make_dirs;
    is_deeply \@s2, [qw(
        t/share/skin/s2/javascript
    )], "s2 make_dirs";
    is_deeply \@s3, [qw(
        t/share/skin/s2/javascript
        t/share/skin/s3/javascript
    )], "s3 make_dirs";
}
