var t = new Test.Wikiwyg();

t.plan(1);

t.run_roundtrip('input');

/* Test
=== WAFL blocks need surrounding vertical whitespace
--- input
top line

middle {search: foo} line

bottom line

*/
