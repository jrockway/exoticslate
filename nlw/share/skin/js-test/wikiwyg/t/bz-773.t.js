var t = new Test.Wikiwyg();

t.filters({
    html: ['html_to_wikitext']
});

t.plan(2);

t.run_is('html', 'text');

/* Test
=== Sanity
--- html
X
Y
Z

--- text
X Y Z

=== Bold tag should not cause linebreak
--- html
X
<b>Y</b>
Z

--- text
X *Y* Z

*/
