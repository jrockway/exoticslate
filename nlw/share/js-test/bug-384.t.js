var t = new Test.Wikiwyg();

var filters = { html: ['html_to_wikitext'] };

t.plan(1);

t.safari_skip_all("we do not convert HTML to wikitext");

t.filters(filters);

t.run_is('html', 'wikitext');

/* Test
=== Indent from simple mode
--- html
<table style="border-collapse: collapse;" class="formatter_table">
<tbody><tr>
<td style="border: 1px solid black; padding: 0.2em; font-weight: bold;">bold</td>
<td style="border: 1px solid black; padding: 0.2em;"><span style="padding: 0.5em;">&nbsp;</span></td>
</tr>
</tbody></table>
--- wikitext
| *bold* |  |

*/
