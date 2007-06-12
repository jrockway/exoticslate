#!perl -w
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 1;
fixtures( 'admin_no_pages' );

filters {
    wiki => 'format',
    match => 'wrap_html',
};

my $hub = new_hub('admin');
my $viewer = $hub->viewer;

run_is wiki => 'match';

sub format {
    $viewer->text_to_html(shift)
}

sub wrap_html {
    <<"...";
<div class="wiki">
$_</div>
...
}

__DATA__
=== Two lists should not have empty paragraph (<br>) between.
--- wiki
* foo

* bar
--- match
<ul>
<li>foo</li>
</ul>
<ul>
<li>bar</li>
</ul>
