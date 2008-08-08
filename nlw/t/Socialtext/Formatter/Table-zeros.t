#!perl -w
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 1;
fixtures( 'admin' );

filters {
    wiki => ['format'],
};

my $hub = new_hub('admin');
my $viewer = $hub->viewer;

run_is wiki => 'match';

sub format {
    $viewer->text_to_html(shift)
}

__DATA__
=== simple table
--- wiki
| 0 | 1 | 1 |
| 1 | 0 | 1 |
| 1 | 1 | 0 |
--- match
<div class="wiki">
<table style="border-collapse: collapse;" class="formatter_table">
<tr>
<td style="border: 1px solid black;padding: .2em;">0</td>
<td style="border: 1px solid black;padding: .2em;">1</td>
<td style="border: 1px solid black;padding: .2em;">1</td>
</tr>
<tr>
<td style="border: 1px solid black;padding: .2em;">1</td>
<td style="border: 1px solid black;padding: .2em;">0</td>
<td style="border: 1px solid black;padding: .2em;">1</td>
</tr>
<tr>
<td style="border: 1px solid black;padding: .2em;">1</td>
<td style="border: 1px solid black;padding: .2em;">1</td>
<td style="border: 1px solid black;padding: .2em;">0</td>
</tr>
</table>
</div>
