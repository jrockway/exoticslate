#!perl
# @COPYRIGHT@

# this test validates that the correct workspace customization attributes
# are "inherited" by newly created workspaces via the web UI

use strict;
use warnings;
use Cwd qw(getcwd);

use Test::More tests => 1;
use Test::Socialtext;
fixtures( 'admin_no_pages' );
use Socialtext::TT2::Renderer;

my $renderer;

BEGIN {
    $renderer = Socialtext::TT2::Renderer->instance;
}

SKIN_RADIO_BUTTON: {
    my $html = $renderer->render(
        template => 'element/settings/list_skipped_files',
        vars     => { skipped_files => ['A', 'B', 'C'], },
        paths => ['share/template'],
    );

    like $html, qr/A, B, C\s*?<\/span>/, 'Files listed';
}
