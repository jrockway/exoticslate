var t = new Test.Wikiwyg();

t.plan(1);

if ( Wikiwyg.is_safari ) {
    t.skipAll("On Safari, we do not convert HTML to wikitext");
}
else {
    t.run_roundtrip('wikitext');
}

/* Test
=== rt:20953 empty heading
--- wikitext
^^^

----

Stuff

*/
