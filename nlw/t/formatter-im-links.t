#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext;
fixtures( 'admin_no_pages' );

my @tests =
    ( [ "An aim link aim:foobar\n" =>
        qr{\Qaim:goim?screenname=foobar\E.+\Qbig.oscar.aol.com/foobar\E} ],
      [ "A yahoo IM link yahoo:barfoo\n" => qr{\Qymsgr:sendIM?barfoo\E} ],
      [ "Another yahoo IM link ymsgr:bubba\n" => qr{\Qymsgr:sendIM?bubba\E} ],
      [ "A skype link callto:JoeSmith\n" => qr{href="callto:JoeSmith"} ],
      [ "A skype link (phone #) callto:1-612-555-9911\n" => qr{href="callto:1-612-555-9911"} ],
      [ "An msn link msn:BillE-G\n" => qr{msn:BillE-G} ],
      [ "An asap link asap:yomama-G\n" => qr{\Qhref="http://asap2.convoq.com/AsapLinks/Meet.aspx?l=yomama\E} ],
    );

plan tests => scalar @tests;

my $hub = new_hub('admin');
my $viewer = $hub->viewer;

for my $test (@tests) {
    my $result = $viewer->text_to_html( $test->[0] );
    chomp(my $name = $test->[0]);
    like( $result, $test->[1], $name );
}
