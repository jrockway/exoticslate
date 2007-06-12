// From https://uj-trac.socialtext.net:447/trac/ticket/232
var t = new Test.Wikiwyg();

var filters = {
    html: ['html_to_wikitext']
};

t.plan(3);

t.filters(filters);

t.run_roundtrip('wikitext');

t.run_is('html', 'text');

/* Test
=== uj-232 - Image urls not roundtripping in IE
--- wikitext
http:base/images/docs/search.png

> http:base/images/docs/search.png

=== wafl inside a P tag works
--- html
<p><span><img alt="base" src="http://talc.socialtext.net:21002/admin/base/images/doc/search.png" border="0"><!-- wiki: http:base/images/docs/search.png --></span></p>
--- text
http:base/images/docs/search.png

=== wafl inside a BLOCKQUOTE tag works
--- html
<blockquote><span><img alt="base" src="http://talc.socialtext.net:21002/admin/base/images/doc/search.png" border="0"><!-- wiki: http:base/images/docs/search.png --></span></blockquote>
--- text
> http:base/images/docs/search.png

*/

