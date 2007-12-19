var t = new Test.Wikiwyg();

t.plan(2);

t.simple_mode_html = true;
t.run_roundtrip('wikitext');

t.simple_mode_html = false;
t.run_roundtrip('wikitext');

/* Test
=== double dashes in as-is phrase
--- wikitext
{{ double -- dash }} problems


*/

