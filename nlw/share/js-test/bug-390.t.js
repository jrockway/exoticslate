var t = new Test.Wikiwyg();

var filters = { html: ['html_to_wikitext'] };

t.plan(1);

t.safari_skip_all("we do not convert HTML to wikitext");

t.filters(filters);

t.run_is('html', 'wikitext');

/* Test
=== A span without style attribute shouln't freeze the browser
--- html
<span class="incipient">ddddddddd</span>
--- wikitext
ddddddddd

*/
