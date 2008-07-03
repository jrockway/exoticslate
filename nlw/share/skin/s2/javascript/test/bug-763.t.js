var t = new Test.Wikiwyg();

t.plan(1);

if (Wikiwyg.is_safari) {
    t.skipAll("testing roundtrip on safari");
}
else {
    t.run_roundtrip('wikitext');
}

/* Test
=== wiitext from bug description
--- wikitext
*Some bold text*.
A sentence no verb
foo bar baz

*some text*.

* [A link]

* [Another link]


*/
