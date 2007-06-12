#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Live fixtures => ['admin'];
Test::Live->new->standard_query_validation;

__DATA__
=== Load up a page
--- query
page_name: admin wiki

=== Save a new revision of the central page
--- form: st-page-editing-form
--- post
page_body: The new page body is short.
--- match
The new page body is short.

=== Remove edit permission for workspace admin
--- do: removePermission workspace_admin edit

=== Load up a page
--- query
page_name: admin wiki

=== Save a new revision of the central page without edit permission
--- form: st-page-editing-form
--- post
page_body: Miniscule
--- match
The new page body is short.
