var t = new Test.Wikiwyg();

t.filters({
    html: ['html_to_wikitext']
});

t.plan(1);
t.run_is('html', 'text');

/* Test
=== Spaces around links
--- html
x<a href="index.cgi?three">y</a>z
x<a href="index.cgi?three">y</a> z
x <a href="index.cgi?three">y</a>z
x <a href="index.cgi?three">y</a> z
--- text
x [y] z
x [y] z
x [y] z
x [y] z

*/
