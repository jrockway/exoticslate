#!perl
# @COPYRIGHT@

use warnings;
use strict;

use Test::Socialtext;
fixtures( 'admin_no_pages' );

filters { regexps => [qw'lines chomp make_regexps'] };
plan tests => 1 * (map { ($_->regexps) } blocks);

my $viewer = new_hub('admin')->viewer;

run {
    my $block = shift;
    my $text = $block->text;
    my $result = $viewer->text_to_html("$text\n");

    for my $re ($block->regexps) {
        like( $result, $re, $text );
    }
};

sub make_regexps { map { s/([\.\+])/\\$1/g; eval } @_ }

__DATA__
===
--- text: cdent@burningchrome.com
--- regexps
qr'<a href="mailto:cdent@burningchrome.com">cdent@burningchrome.com</a>'

===
--- text: cdent@burningchrome.com.
--- regexps
qr'<a href="mailto:cdent@burningchrome.com">cdent@burningchrome.com</a>.'

===
--- text: mail cdent@burningchrome.com, not somebody else.
--- regexps
qr'<a href="mailto:cdent@burningchrome.com">cdent@burningchrome.com</a>, not '

===
--- text: cdent@com.
--- regexps
qr'^cdent@com.'m

===
--- text: cdent@hot.burningchrome.com.
--- regexps
qr'<a href="mailto:cdent@hot.burningchrome.com">cdent@hot.burningchrome.com</a>.'

===
--- text: workspace+category_foo@socialtext.net
--- regexps
qr'<a href="mailto:workspace+category_foo@socialtext.net">workspace+category_foo@socialtext.net</a>'

===
--- text: workspace+category_foo@socialtext.net.
--- regexps
qr'<a href="mailto:workspace+category_foo@socialtext.net">workspace+category_foo@socialtext.net</a>.'

