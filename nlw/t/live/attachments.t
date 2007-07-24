#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Live fixtures => ['admin'];
Test::Live->new()->standard_query_validation;
__DATA__
=== Get main page
--- request_path: /admin/index.cgi?admin_wiki
--- match: home page

=== Attach a file
--- form: attachForm
--- post
file: t/extra-attachments/live/attachments.t/test.txt
--- match: test\.txt

=== Reload page
--- request_path: /admin/index.cgi?admin_wiki

=== Make sure attachment has correct data
--- follow_link
text: test.txt
n: 1
--- match_file: t/extra-attachments/live/attachments.t/test.txt

=== Back to the home page
--- request_path: /admin/index.cgi?admin_wiki
--- match: home page

=== Attach a binary file
--- form: attachForm
--- post
file: t/extra-attachments/live/attachments.t/thing.png
--- match
test\.txt
thing\.png

=== Back to the home page
--- request_path: /admin/index.cgi?admin_wiki
--- match
test\.txt
thing\.png
