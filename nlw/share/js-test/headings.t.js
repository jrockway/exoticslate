var t = new Test.Wikiwyg();

t.plan(3);

t.run_roundtrip('wikitext');
t.run_roundtrip('wikitext1', 'wikitext2');

/* Test
=== rt:20953 empty heading
--- wikitext
^^^

----

Stuff

=== 22003 failure from big test
--- wikitext1
^^ Heading

This is a paragraph:
{category_list: welcome}

--- wikitext2
^^ Heading

This is a paragraph:

{category_list: welcome}

=== All headers with intermediate blocks
--- wikitext
^ One

lala

^^ Two

* flee

^^^ Three

^^^^ Four

| xxy |

^^^^^ Five

> hi

^^^^^^ Six

*/
