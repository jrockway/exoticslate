#!perl
# @COPYRIGHT@

# this test validates that the correct workspace customization attributes
# are "inherited" by newly created workspaces via the web UI

use strict;
use warnings;
use Cwd qw(getcwd);

use Test::More tests => 7;
use Test::Socialtext;
fixtures( 'admin_no_pages' );
use Socialtext::TT2::Renderer;

my $renderer;

BEGIN {
    $renderer = Socialtext::TT2::Renderer->instance;
}

SKIN_RADIO_BUTTON: {
    my $html = $renderer->render(
        template => 'element/settings/workspaces_settings_skin_section',
        vars     => { wiki => {skin => 'st', name => 'admin' }, },
        paths => ['share/template'],
    );

    like $html, qr/<input id="st-workspaceskin-default" type="radio" name="skin_name" value="st" checked/, 'default skin selected';
    like $html, qr/<input id="st-workspaceskin-custom" type="radio" name="skin_name" value="admin" >/, 'custom skin not selected';

    $html = $renderer->render(
        template => 'element/settings/workspaces_settings_skin_section',
        vars     => { wiki => {skin => 'admin', name => 'admin' }, },
        paths => ['share/template'],
    );

    like $html, qr/<input id="st-workspaceskin-default" type="radio" name="skin_name" value="st" >/, 'default skin is not selected';
    like $html, qr/<input id="st-workspaceskin-custom" type="radio" name="skin_name" value="admin" checked >/, 'custom skin is selected';
}

NO_FILES: {
    my $html = $renderer->render(
        template => 'element/settings/workspaces_settings_skin_section',
        vars     => { wiki => {skin => 'new', name => 'admin', skin_files => [] }, },
        paths => ['share/template'],
    );

    like $html, qr/<div class="workspace-entry-p" style="display: none;">/, 'Files title hidden with no files and custom skin';
    like $html, qr/<table class="standard-table" style="display: none;">/, 'File table hidden with no files and custom skin';
}

IS_DEFAULT_SKIN: {
    my $html = $renderer->render(
        template => 'element/settings/workspaces_settings_skin_section',
        vars     => {
            wiki => {skin => 'st', name => 'admin'},
            skin_files => [{name => 'test1', size => 132456, date => '2007-07-15'}],
        },
        paths => ['share/template'],
    );

    like $html, qr/<table class="standard-table"\s*>/, 'File table is block: display with files and default skin';
}
