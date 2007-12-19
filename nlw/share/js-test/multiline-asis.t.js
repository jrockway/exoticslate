// https://uj-trac.socialtext.net:449/trac/ticket/326

var t = new Test.Wikiwyg();

t.plan(1);

t.run_roundtrip('wikitext');

/* Test
=== uj-326 - Multiline asis roundtrips
--- wikitext
{{ *this text is not bold*
_neither is this text italic_ }}

*/
