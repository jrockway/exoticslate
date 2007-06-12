#!perl -w
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext;

fixtures( 'admin_no_pages' );

# Need to load this after the shortcuts.yaml file is created.
require Socialtext::ShortcutLinksPlugin;


my @tests = (
    [ "RT Wafl {rt 1002} foo" =>
        qr{\Q<a href="http://rt.socialtext.net/Ticket/Display.html?id=1002">1002</a>}],
    [ "RT Queue {rtqueue Release Tasks} message" =>
        qr{\Q<a href="https://rt.socialtext.net:444/Search/Results.html?Order=ASC&amp;Query=Queue='Release Tasks'%20AND%20(Status='open'%20OR%20Status='new')&amp;Rows=50&amp;OrderBy=id&amp;Page=1">}],
    [ "Google Wafl {google socialtext} foo" =>
        qr{\Q<a href="http://www.google.com/search?q=socialtext">socialtext</a>}],
    [ "Google Wafl {google foo bar bat} foo" =>
        qr{\Q<a href="http://www.google.com/search?q=foo bar bat">foo bar bat</a>}],
    [ "Escaped href {svn 5678} foo" =>
        qr{\Q<a href="https://repo.socialtext.net/listing.php?rev=5678&amp;sc=1">5678</a>}],

    # Test positional parameters, too
    [ "Mailing list {devlist 2006-March 004454} message" =>
        qr{\Q<a href="http://lists.socialtext.net/private/dev/2006-March/004454.html">2006-March 004454</a>}],
);

plan tests => scalar @tests;

my $hub = new_hub('admin');

for my $test ( @tests ) {
    my ( $source, $regex ) = @$test;

    # The "\n" is necessary to insure wafl is seen
    my $result = $hub->viewer->text_to_html( "$source\n");
    like( $result, $regex, $source );
}
