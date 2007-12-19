var t = new Test.Wikiwyg();

t.plan(1);

t.run_roundtrip('wikitext');

/* Test
=== Text disappears after two lists.
--- wikitext
# xxx

# yyy

zzz

*/
