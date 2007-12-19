var t = new Test.Wikiwyg();

t.plan(8);

t.simple_mode_html = true;
t.run_roundtrip('wikitext');

t.simple_mode_html = false;
t.run_roundtrip('wikitext');

/* Test
=== Raw HTML Blocks
--- wikitext
.html
<h1>Hello</h1>

<p>I'll find you in heaven.</p>
.html

.html
<!-- A comment -->
<ul>
<li>(double dash bugs)--</li>
</ul>
.html

=== Selenium Block
--- wikitext
.selenium
== Run The Javascript Unit Tests

open
/static/1.1.1.1/js-test/run/14988.t
.selenium

=== Wikiwyg Formatting Test
--- wikitext
.wikiwyg_formatting_test
<div class="wiki"><span style="font-style: italic;">one</span><br
style="font-style: italic;"><br style="font-style: italic;"><span
style="font-style: italic;">two</span><br></div>
.wikiwyg_formatting_test

foo

=== .html after paragraph
--- wikitext
Sales, Europe

This wiki is

.html
<div style="height:500px;width:500px"></div>
.html

*/
