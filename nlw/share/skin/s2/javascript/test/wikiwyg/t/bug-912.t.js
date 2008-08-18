var t = new Test.Wikiwyg();

t.filters({
    html: ['html_to_wikitext']
});

t.plan(2);
t.run_is('html', 'text');

/* Test
=== Spaces around links when surrounded by word characters
--- html
x<a href="index.cgi?y">y</a>z
x<a href="index.cgi?y">y</a> z
x <a href="index.cgi?y">y</a>z
x <a href="index.cgi?y">y</a> z
--- text
x [y] z
x [y] z
x [y] z
x [y] z

=== No spaces around links when surrounded by non-word characters
--- html
!<a href="index.cgi?y">y</a>!
--- text
![y]!

*/
