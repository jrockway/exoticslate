var t = new Test.Wikiwyg();

t.plan(9);

t.run_roundtrip('wikitext');
t.run_roundtrip('wikitext1', 'wikitext2');

/* Test
=== Simple Sentence with Bold Word
--- wikitext
This *is* it.

=== Simple Sentence with Two Bold Words
--- wikitext
This *is* it *also*.

=== Two Paragraphs
--- wikitext
This is paragraph 1

This is paragraph 2

=== Two Multiline Paragraphs
--- wikitext
This is
paragraph 1

This is
paragraph 2

=== Bold Italic Strike and TT
--- wikitext
This has *bold words*, _italic text_ and -strike
through- and `tt text`.

=== Four kinds of paragraphs
--- wikitext
And then there are* cases *where bolding shouldn't happen. There are times
when --> you don't expect --> strikethrough, but it happens.

Go to <http://foo.com/>.

*yo*. /yo/ . yo

This is *bold* _italic_ -strike- `monospace` yo

=== Collapse Blanks
--- wikitext1
I like pie.  Not too hot.    Not too cold.
--- wikitext2
I like pie. Not too hot. Not too cold.

=== Collapse Blank Lines
--- wikitext1
one

 

two

 

 
three
--- wikitext2
one

two

three

=== Trailing Blanks
--- wikitext1
getting your additional thoughts/needs!   
 
Socialtext: The Leader in Social Software
--- wikitext2
getting your additional thoughts/needs!

Socialtext: The Leader in Social Software

*/

