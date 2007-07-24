#!perl -w

use strict;
use warnings;

# @COPYRIGHT@
use Test::Live fixtures => ['admin'];

$Test::Live::Order_doesnt_matter = $Test::Live::Order_doesnt_matter = 1;

Test::Live->new->standard_query_validation;
__DATA__
=== Hit a non-existent page
--- do: cleanCeqlotron
--- request_path: /admin/index.cgi?Velcro
--- match
Replace this text with your own

=== save the page
--- form: st-page-editing-form
--- post
page_body: This page is about to have attachments stuck to it...
--- match
This page is about to have attachments stuck to it...

=== search for "stuck"
--- do: runCeqlotron
--- form: 1
--- post
search_term: stuck
--- match
Velcro

=== Go back to our page
--- request_path: /admin/index.cgi?Velcro
--- match
This page is about to have attachments stuck to it...

=== attach doc with '#' in the name.
--- form: attachForm
--- post
file: t/extra-attachments/FormattingTest/Rule #1

=== Make sure page has attachment
--- request_path: /data/workspaces/admin/pages/velcro/attachments
--- match: Rule #1

=== Go back to our page
--- request_path: /admin/index.cgi?Velcro

=== attach foo.txt (will be overridden)
--- form: attachForm
--- post
file: t/attachments/same-name-different-content/foo.txt

=== Make sure page has attachment
--- request_path: /data/workspaces/admin/pages/velcro/attachments
--- match: foo\.txt

=== Go back to our page
--- request_path: /admin/index.cgi?Velcro

=== attach new foo.txt (snippet of johnt & autarch talking)
--- form: attachForm
--- post
file: t/attachments/foo.txt

=== Make sure page has 2 copies of foo.txt
--- request_path: /data/workspaces/admin/pages/velcro/attachments
--- match: foo\.txt
--- match: foo\.txt

=== Go back to our page again
--- request_path: /admin/index.cgi?Velcro
--- match
Velcro

=== search attachments
--- do: runCeqlotron
--- form: displaySearchForm
--- post
search_term: autarch
--- match
Velcro
foo.txt

=== Go back to our page again
--- request_path: /admin/index.cgi?Velcro
--- match
Velcro

=== attach revolts.doc (says something about tocqueville)
--- form: attachForm
--- post
file: t/attachments/revolts.doc

=== Make sure page has attachment
--- request_path: /data/workspaces/admin/pages/velcro/attachments
--- match: revolts\.doc

=== Go back to our page again
--- request_path: /admin/index.cgi?Velcro

=== search word attachment
--- do: runCeqlotron
--- form: displaySearchForm
--- post
search_term: tocqueville
--- match
revolts.doc

=== Go back to our page again
--- request_path: /admin/index.cgi?Velcro
--- match
Velcro

=== attach t/attachments/tree.zip (vim colorscheme files (example: "ctermfg"))
--- SKIP: XXX Uh-oh... may be a bug (or I'm just tired)
--- form: attachForm
--- post
file: t/attachments/tree.zip
embed: 1
unpack: 1
--- match
pablo  (...todo: find out what the "expected" is, here)
