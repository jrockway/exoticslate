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
--- match
filename":"Rule #1"

=== Go back to our page
--- request_path: /admin/index.cgi?Velcro
--- match
href="/admin/index.cgi/Rule%20%231\?action=attachments_download

=== attach foo.txt (will be overridden)
--- form: attachForm
--- post
file: t/attachments/same-name-different-content/foo.txt
--- match
filename":"foo.txt"

=== Go back to our page
--- request_path: /admin/index.cgi?Velcro
--- match
<a href="/admin/index.cgi/foo.txt\?action=attachments_download;page_name=velcro;id=.*">foo.txt</a>

=== attach new foo.txt (snippet of johnt & autarch talking)
--- form: attachForm
--- post
file: t/attachments/foo.txt
--- match
filename":"foo.txt"

=== Go back to our page
--- query
action: display
page_name: Velcro
--- match
<a href="/admin/index.cgi/foo.txt\?action=attachments_download;page_name=velcro;id=.*">foo.txt</a>
<a href="/admin/index.cgi/foo.txt\?action=attachments_download;page_name=velcro;id=.*">foo.txt</a>

=== Go back to our page again
--- request_path: /admin/index.cgi?Velcro
--- match
Velcro

=== search attachments
--- do: runCeqlotron
--- form: searchForm
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

=== Go back to our page again
--- request_path: /admin/index.cgi?Velcro
--- match
<a href="/admin/index.cgi/revolts.doc\?action=attachments_download;page_name=velcro;id=.*">revolts.doc</a>

=== search word attachment
--- do: runCeqlotron
--- form: searchForm
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
