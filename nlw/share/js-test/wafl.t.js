var t = new Test.Wikiwyg();

t.plan(8);

t.simple_mode_html = true;
t.run_roundtrip('wikitext');

t.simple_mode_html = false;
t.run_roundtrip('wikitext');

/* Test
=== TOC Wafl
--- wikitext
foo

{toc: }

foo

=== Link with a '-'
--- wikitext
{link: dev-tasks [wiki 101]}

=== One blank line between header and a wafl-p
--- wikitext
^^ Wafl without a colon

{link: public [wiki 101]}

=== Include followed by a header
--- wikitext
{include: [Extralink]}

^^ Hack #2

*/
