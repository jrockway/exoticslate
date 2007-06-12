var t = new Test.Wikiwyg();
t.plan(1);

if (Wikiwyg.is_safari) {
    t.skipAll("testing roundtrip on safari");
}
else {
    t.run_roundtrip('wikitext');
}


/* Test
=== space before a wafl phrases are kept
--- wikitext
foo {image: bar.jpg}

*/

