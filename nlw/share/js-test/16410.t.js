var t = new Test.Wikiwyg();
t.plan(2);

t.run_roundtrip('wikitext');

t.simple_mode_html = false;
t.run_roundtrip('wikitext');

/* Test
=== space before a wafl phrases are kept
--- wikitext
foo {image: bar.jpg}

*/
