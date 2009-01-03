var t = new Test.Wikiwyg();

t.filters({
    html: ['html_to_wikitext']
});

t.plan(2);

t.run_is('html', 'text');

/* Test
=== H1 Bold with span
--- html
<h1><span style="font-weight: bold;">X</span></h1>

--- text
^ *X*

=== H1 Bold with attr
--- html
<h1 style="font-weight: bold;">X</h1>

--- text
^ *X*

*/
