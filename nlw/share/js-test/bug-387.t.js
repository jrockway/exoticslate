var t = new Test.Wikiwyg();

var filters = { html: ['html_to_wikitext'] };

t.plan(3);

t.safari_skip_all("we do not convert HTML to wikitext");

t.filters(filters);

t.run_is('html', 'wikitext');

/* Test
=== Indent from simple mode
--- html
<div style="margin-left: 40px;">yyy<br></div>
--- wikitext
> yyy

=== Indent from simple mode
--- html
<div class="wiki">xxx<br class="p"><br class="p">
<p style="margin-left: 40px;">
yyy</p>zzz<br class="p"><br class="p">
<br></div>
--- wikitext
xxx

> yyy

zzz

=== Indent more from simple mode
--- html
<div style="margin-left: 40px;">xxx<br></div><div style="margin-left: 80px;">yyy<br></div><div style="margin-left: 40px;">zzz<br></div>
--- wikitext
> xxx
>> yyy
> zzz

*/
