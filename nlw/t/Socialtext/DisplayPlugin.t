#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 7;
fixtures( 'admin' );

BEGIN {
    use_ok( 'Socialtext::DisplayPlugin' );
    use_ok( 'Socialtext::Page' );
}

my $hub = new_hub('admin');

# Make sure the display action returns the "furniture" we expect it to.
DISPLAY: {
    my $page = Socialtext::Page->new( hub => $hub )->create(
        title   => "Zac's First Page",
        content => "^ Header One\n\nHello World!\n",
        creator => $hub->current_user(),
    );

    $hub->pages->current($page);

    my $output = $hub->display->display();

    ok( $output ne '', 'output exists' );
    like( $output, qr/<div id="st-page-content">/,
        'checking for screen layout' );
    like(
        $output, qr/<span id="st-page-titletext">.*Zac's First Page/s,
        'checking for title'
    );

    unlike(
        $output, qr/called at lib\/.*line\s\d+/,
        'does not have error output'
    );

}

# FIXME: This is just testing a specific bug. More detailed analysis
# of the data structure is warranted at some time.
PAGE_INFO_HASH: {
    my $page = $hub->pages->new_from_name("Zac's First Page");

    my $hash = $hub->display->_get_page_info($page);

    like $hash->{has_stats}, qr{^\d+$}, "has_stats contains a digit";
}
