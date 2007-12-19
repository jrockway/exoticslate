var t = new Test.Wikiwyg();

t.plan(1);

t.run_roundtrip('wikitext');

/* Test
=== .html sections don't get messed up in IE 7
--- wikitext
foo

.html
bar
.html

baz

*/
var t = new Test.Wikiwyg();

t.plan(1);

t.run_roundtrip('wikitext');

/* Test
=== .html sections don't get messed up in IE 7
--- wikitext
foo

.html
bar
.html

baz

*/
