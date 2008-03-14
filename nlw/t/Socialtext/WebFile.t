#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 4;
fixtures( 'admin' );

use Socialtext::CSS;
use Data::Dumper;

my $version = $Socialtext::VERSION;
my $css = Socialtext::CSS->new( hub => new_hub('admin') );

$css->add_file('weblog.css');

CHECK_BASE: {
    my @files = sort $css->files();
    my @uris  = sort $css->uris();
    for my $f ( qw( screen.css ) ) {
        my @match_files = grep { m{\Q/skin/s2/css/$f} } @files;
        is( scalar @match_files, 1, "$f is in list of CSS files" );

        my @match_uris = grep { m{\Q/static/$version/skin/s2/css/$f} } @uris;
        is( scalar @match_uris, 1, "$f is in list of CSS uris, with NLW version" );
    }
}

CHECK_SHARED: {
    $css->add_path('skin/cex/css');
    $css->add_file('screen.css');

    my @files = $css->files();

    my @match_files = grep { m{\Q/skin/cex/css/screen.css} } @files;
    is( scalar @match_files, 1, 'screen.css is in list of CSS files' );

    my @uris = $css->uris();
    my @match_uris = grep { m{\Q/static/$version/skin/cex/css/screen.css} } @uris;
    is( scalar @match_uris, 1, 'screen.css is in list of CSS uris, with NLW version' );
}
