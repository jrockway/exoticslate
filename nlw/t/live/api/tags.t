#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Live fixtures => ['admin_with_extra_pages', 'help'];
my $LiveTest = Test::Live->new();
$LiveTest->standard_query_validation;

__DATA__
=== First page should have no tags
--- request_path: /page/admin/wikiwygformattingtodo/tags
--- accept: text/plain
--- match_noreturn

=== First page should have no tags - JSON
--- request_path: /page/admin/wikiwygformattingtodo/tags
--- accept: text/javascript
--- match: \[\]

=== Unsupported accept type defaults to text
--- request_path: /page/admin/wikiwygformattingtodo/tags
--- accept: text/html
--- match_noreturn

=== Get tag list via JSON
--- request_path: /page/admin/conversations/tags
--- accept: text/javascript
--- match: {"maxCount":18,"tags":\[{"count":18,"tag":"Welcome"}\]}

=== Get tag list via text
--- request_path: /page/admin/conversations/tags
--- accept: text/plain
--- match: Welcome

=== Put a tag
--- request_path: /page/admin/wikiwygformattingtodo/tags
--- put: Shawn
--- accept: text/javascript
--- match_status: 201
--- match: {"maxCount":18,"tags":\[{"count":1,"tag":"Shawn"}\]}

=== Put a UTF-8 tag
--- request_path: /page/admin/wikiwygformattingtodo/tags
--- put: Και
--- accept: text/javascript
--- match_status: 201
--- match: {"maxCount":18,"tags":\[{"count":1,"tag":"Shawn"},{"count":1,"tag":"%CE%9A%CE%B1%CE%B9"}\]}

=== Should be 2 Shawn tags
--- request_path: /page/admin/people/tags
--- put: Shawn
--- accept: text/javascript
--- match_status: 201
--- match: {"maxCount":18,"tags":\[{"count":18,"tag":"Welcome"},{"count":2,"tag":"Shawn"}\]}

=== Delete a tag
--- request_path: /page/admin/conversations/tags
--- delete: Welcome
--- accept: text/javascript
--- match_status: 200
--- match: \[\]

=== Page should have no tags
--- request_path: /page/admin/conversations/tags
--- accept: text/javascript
--- match: \[\]

=== Add a tag to a page that does not exist
--- request_path: /page/admin/ssjjkk/tags
--- put: Shawn
--- accept: text/javascript
--- match_status: 404

=== Delete a non-existant tag
--- request_path: /page/admin/conversations/tags
--- delete: Webo
--- accept: text/javascript
--- match_status: 404
--- match_noreturn: \[\]
