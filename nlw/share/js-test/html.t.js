var t = new Test.Wikiwyg();

var filters = {
    html: ['html_to_wikitext']
};

t.plan(1);

if ( Wikiwyg.is_safari ) {
    t.skipAll("On Safari, we do not convert HTML to wikitext");
}
else {
    t.filters(filters);
    t.run_is('html', 'wikitext');
}

/* Test
=== Code variations work
--- html
<ul>
<li><code>foo</code></li>
<li><kbd>bar</kbd></li>
<li><var>baz</var></li>
<li><samp>quux</samp></li>
</ul>
--- wikitext
* `foo`
* `bar`
* `baz`
* `quux`

=== Pass and skip
--- SKIP
Was causing issue on IE. Fix later.
--- html
<p>
This should be <button>gone</button>.<br />
This should lose <abbr>markup</abbr>.
</p>
--- wikitext
This should be .
This should lose markup.

*/
