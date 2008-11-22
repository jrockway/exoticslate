var t = new Test.Wikiwyg();

t.plan(1);

t.run_roundtrip('input');

/* Test
=== Inline WAFL blocks should not add extra vertical whitespace
--- input
top line

middle {search: foo} line

bottom line

*/
