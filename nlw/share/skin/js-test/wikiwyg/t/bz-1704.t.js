var t = new Test.Wikiwyg();

t.filters({
    html: ['html_to_wikitext']
});

t.plan(1);

t.run_is('html', 'text');

/* Test
=== Empty anchor elements should render into nothing
--- html
<table><tbody><tr><td><span>1<br/><br/>2</span></td></tr></tbody></table>

--- text
| 1

2|

*/
