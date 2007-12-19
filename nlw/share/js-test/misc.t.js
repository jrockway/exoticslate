var t = new Test.Wikiwyg();

t.plan(3);

t.run_roundtrip('wikitext');

/* Test
=== Toc failure bug
--- wikitext
{toc: Replace} this text with your own.

=== TT paragraph after heading
--- wikitext
^^ `set` improvements

`set` should strip surrounding backticks, unless the first backtick is escaped with a \, in which case no backticks should be stripped.

=== TT paragraph after heading
--- wikitext
> I think the ideal thing

* Minify combined-sources.js

*/
