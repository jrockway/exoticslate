var t = new Test.Wikiwyg();

t.plan(13);

t.run_roundtrip('wikitext');
t.run_roundtrip('wikitext1', 'wikitext2');

/* Test
=== Two unordered lists
--- wikitext
* one
* two

* three
* four

=== Two ordered lists
--- wikitext
# one
# two

# three
# four

=== Ordered and unordered lists
--- wikitext
# one
# two

* three
* four

# five
# six

* seven
* eight

=== Complex unordered lists
--- wikitext
* one
** two
** three
*** four
* five
*** six

=== Complex ordered lists
--- wikitext
# one
## two
## three
### four
# five
### six

=== Mixed Ordered/Unordered Lists
--- wikitext
# one
** foo
** bar
# two

=== Mixed Ordered/Unordered Lists
--- wikitext
* foo
## one
## two
* bar

=== List of bolds
--- wikitext
* *foo*
* *bar baz* quux

=== List of sharps
--- wikitext
# #foo#
# # bar baz quux

=== Lists of bolds and sharps
--- wikitext
* *foo*
## #foo#

=== List followed by asis
--- wikitext
* foo

{{ bar }}

=== List with empty lines
--- wikitext
*
*

=== Blank at end of list item
--- wikitext1
* foo: 
## bar
--- wikitext2
* foo:
## bar

*/
