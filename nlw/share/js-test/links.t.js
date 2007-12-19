var t = new Test.Wikiwyg();

t.plan(15);

var filters = { wikitext: ['template_vars'] };

t.filters(filters);

t.run_roundtrip('wikitext');

/* Test
=== From 17312.t
--- wikitext
"Name of this Link"<[%THIS_URL%]?page_name>

=== A regular wiki link 
--- wikitext
* A link to [That Page].

=== A renamed link
--- wikitext
A link to "Foo Fighting"[That Page].

=== A http link
--- wikitext
Go to <http://foo.com/>.

=== A renamed http link
--- wikitext
"A link"<http://foobar.com>
Foobar

=== Question mark after link
--- wikitext
* Question after URL <http://foo.com>?

=== Mailto link
--- wikitext
* casey.west@socialtext.com

=== Named mailto link
--- wikitext
* "Casey West Email"<mailto:casey.west@socialtext.com>

=== Keep ears in italics
--- wikitext
* _<http://sunirlikesthemitalicizedurls.com>_

=== Keep ears when ending in italics
--- wikitext
* _Hey <http://sunirlikesthemitalicizedurls.com>_

=== Unadorned Image URL's
--- wikitext
* http://www2.socialtext.net/dev-tasks/Onit_Logo.png

=== HTTP link on line by itself
--- wikitext
http://www.flickr.com/photos/cdent/271626476/

=== HTTP link on line by itself after another line
--- wikitext
Chris' photos:
http://www.flickr.com/photos/cdent/271626476/

=== HTTP link on line by itself after another line and blank line
--- wikitext
Hi

Here we are on flickr:

http://flickr.com/photos/tags/socialtext/

=== Strip ears from quoted links
--- wikitext
* 'http://no.space.before.link is a great site'

*/
