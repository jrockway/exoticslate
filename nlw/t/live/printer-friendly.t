#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Live fixtures => ['admin_with_extra_pages'];
Test::Live->new()->standard_query_validation;
__DATA__
=== Display the FormattingTest as printer-friendly
--- query
action: display_html
page_name: FormattingTest
--- match
css/st/screen.css
NotALink
--- nomatch
foobar//foobar
