var t = new Test.Wikiwyg();

t.plan(2);

t.run_roundtrip('wikitext');

/*
Porting tests from:
14988
15858
*/

/* Test
=== Single blank line preserved
--- wikitext
foo

bar

=== preserve newlines
--- wikitext
one
two
three

*/
