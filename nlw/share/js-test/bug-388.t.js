var t = new Test.Wikiwyg();

var filters = { html: ['html_to_wikitext'] };

t.plan(2);

t.safari_skip_all("we do not convert HTML to wikitext");

t.filters(filters);

t.run_is('html', 'wikitext');

/* Test
=== Bold, italic and strike from simple to advanced
--- html
<span style="font-weight: bold; font-style: italic; text-decoration: line-through;">abcd</span>
--- wikitext
-_*abcd*_-

=== Bold and strike from simple to advanced
--- html
<span style="font-weight: bold; text-decoration: line-through;">abcd</span>
--- wikitext
-*abcd*-

*/
