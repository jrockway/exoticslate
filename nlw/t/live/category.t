#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Live fixtures => ['admin'];
Test::Live->new()->standard_query_validation;
__DATA__
=== 'Start here' page
--- request_path: /admin/index.cgi?Start_here
--- match
st-tags-initial.*"tag"\:"Welcome"

=== List all categories
--- query
action: category_list
--- match
Welcome

=== And view as weblog
--- query
action: weblog_display
category: Welcome
--- MATCH_WHOLE_PAGE
--- match
Weblog: Welcome
New.*Post
or post by email
href="mailto:admin\+Welcome@[\w.]+"
