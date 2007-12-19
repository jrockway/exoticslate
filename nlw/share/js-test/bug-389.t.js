var t = new Test.Wikiwyg();

var filters = { html: ['html_to_wikitext'] };

t.plan(3);

t.safari_skip_all("we do not convert HTML to wikitext");

t.filters(filters);

t.run_is('html', 'wikitext');

/* Test
=== hr in li
--- html
<FONT style="BACKGROUND-COLOR: #ffffdd">
<UL>
<LI><FONT style="BACKGROUND-COLOR: #ffffdd">xxx</FONT></LI>
<LI>
<HR>
</LI>
<LI><FONT style="BACKGROUND-COLOR: #ffffdd">yyy</FONT></LI></UL></FONT>
--- wikitext
* xxx
*
* yyy

=== hr in li
--- html
<OL>
<LI><FONT style="BACKGROUND-COLOR: #ffffdd">xxx</FONT></LI>
<LI>
<HR>
<FONT style="BACKGROUND-COLOR: #ffffdd">yyy</FONT></LI>
<LI><FONT style="BACKGROUND-COLOR: #ffffdd">zzz</FONT></LI></OL>
--- wikitext
# xxx
# yyy
# zzz

=== hr in li
--- html
<OL>
<LI><FONT style="BACKGROUND-COLOR: #ffffdd">xxx</FONT></LI>
<LI><FONT style="BACKGROUND-COLOR: #ffffdd">yyy 
<HR>
zzz</FONT></LI>
<LI><FONT style="BACKGROUND-COLOR: #ffffdd">123</FONT></LI></OL>
--- wikitext
# xxx
# yyy zzz
# 123

*/
