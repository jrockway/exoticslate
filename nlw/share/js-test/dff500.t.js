var t = new Test.Wikiwyg();

t.plan(40);

t.simple_mode_html = true;
t.run_roundtrip('wikitext');

t.simple_mode_html = false;
t.run_roundtrip('wikitext');

t.run_roundtrip('wikitext1', 'wikitext2');

/* Test
=== Indented lines.
--- wikitext
1
 2
  3
   4

=== Indented lines.
--- wikitext
 *Up:* [xxxx]
 *Next:* [yyyy]

=== Leading spaces
--- wikitext
 http://foo.com
 http://bar.com

=== Image url in table
--- wikitext
| http://foo.com/l1a.gif | "David"<http://foo.com/cises> |

=== Spaces after asis (this already worked but adding to protect)
--- wikitext
| {{ {search-full: title:comments} }}include pages with "comments" in title |
| {{ {search-full: title:comments} }} include pages with "comments" in title |

=== Image link madness
--- wikitext
http://foo.com/baz.jpg Bar<BR>

=== More image link madness
--- wikitext
> Foo http://foo.com/bar.gif lalala

=== embeded html
--- wikitext
.html
<a href="javascript:void(furlit=window.open('http://66.160.142.4/bk.php?s=f&to=0&ti='));">POST</a>
.html

=== embeded javascript
--- wikitext
.html
if (foo && bar) return;
.html

=== image in a list
--- wikitext
# foo
# foo http://foo.com/foo.jpg
# foo

=== Table Madness
--- SKIP
XXX - Requires formatter fix
--- wikitext
| 
> and a one | 
# and a two | 
* and a three | 
^^^^ and a four |

=== Two url lines, second one is image
--- wikitext
http://www.org/lollers.html
http://www.org/lolknuth.gif

=== Weird underscores
--- SKIP
XXX - Requires formatter fix
--- wikitext
This is it: _ __ __ __ _. you know?

=== Line of images
--- wikitext
http://foo.com/bar.jpg http://foo.com/bar2.jpg http://foo.com/bar3.jpg

=== (Bogus) Link with ) in it
--- wikitext
# wget http://s.so.net/S.tar.gz (or your preferred mirror <http://so.net/beta.tar.gz?download )>

=== two includes
--- wikitext
{include: [menu]}
{include: [Stax: Menu Mover]}

=== two includes
--- wikitext
{include: [menu]} {include: [Stax: Menu Mover]}

=== Blank two level indent
--- wikitext
* Foo
**
* Bar
##
**

=== Image after two paragraphs
--- wikitext
xxxx

yyy

http://foo.com/bar.jpg

=== We messed this up somehow
--- wikitext
www

xxx

yyy _zzz_

=== list inside table
--- wikitext
| foo | 
* one
* two | 
> bar
> bar | ^^ Hello
| xxx |

=== Line in a paragraph starting with space star
--- SKIP
XXX - This is a formatter oddness. It thinks 'man' is bold.
--- wikitext
Foo
 * yowza *man
 * kitty
 * kat

=== Single URL in a line
--- SKIP
XXX - Requires formatter fix
Technically it is currently ok, because we don't allow caps in 'http://',
but we should.
--- wikitext1
lalala

<Http://foo.com>

--- wikitext2
lalala

Http://foo.com

=== Strip extra blanks in indented
--- wikitext1
>>in the first line of the e-mail. 
--- wikitext2
>> in the first line of the e-mail.

=== Blank after indent
--- wikitext1
> foo 
>> foo
--- wikitext2
> foo
>> foo

*/
