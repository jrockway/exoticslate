var t = new Test.Wikiwyg();

t.plan(1);

t.run_roundtrip('input', 'output');

/* Test
=== WAFL blocks need surrounding vertical whitespace
--- input
top

foo {search: bar} baz

bottom

--- output
top

foo

{search: bar}

baz

bottom

*/
