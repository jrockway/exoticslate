var t = new Test.Wikiwyg();

var filters = {
    html: ['html_to_wikitext']
};

t.plan(2);

if ( Wikiwyg.is_safari ) {
    t.skipAll("On Safari, we do not convert HTML to wikitext");
}
else {
    t.filters(filters);
    if ( Wikiwyg.is_ie ) {
        t.skip("IE doesn't have this problem.");
    } else {
        t.run_is('html', 'wikitext');
    }
    t.run_roundtrip_async('wikitext');
}

/* Test
=== A bold becomes a br
--- html
<div class="wiki">
<p>
xxx <span style="font-weight: bold;">aaa bbb<br></span></p>
<br></div>
--- wikitext
xxx *aaa bbb*

*/

