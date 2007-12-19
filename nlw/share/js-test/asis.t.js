var t = new Test.Wikiwyg();

t.plan(10);

t.simple_mode_html = true;
t.run_roundtrip('wikitext');

t.simple_mode_html = false;
t.run_roundtrip('wikitext');
 
/* Test
=== From asis-roundtrip.t.js
--- wikitext
{{ {*asis* _without_ -any- [escaped html entities]} }}

=== From asis-roundtrip.t.js
--- wikitext
{{ {random "insane"<asis> [mark up]} *all* _on_ -one- *line* }}

=== From [Most Wanted Pages]
--- wikitext
{{[ < > & &amp; $lt; &gt; ]}}

=== Escaped wafl
--- wikitext
* Escaped wafl {{{foo}}}

=== wafl literals in asis
--- wikitext
Real wafl {{ {link:foo} or {link: foo} or {link foo} or {tm};}} only


*/
