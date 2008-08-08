#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 1;
fixtures( 'admin' );
use Socialtext::Encode;

my $hub = new_hub('admin');

{
    my $content = ".html\n<div>one\n.html\n";
    my $page = make_new_page("Formatter Test for html wafl blocks");

    $page->content($content);
    my $html = $page->to_html;

    (my $display = $content) =~ s/\n/\\n/g;
    like($html, qr[
                    <div\s+class="wafl_block"><div>one\s+</div>\n
                    <!--\s+wiki:\n
                    .html\n
                    <div>one\n
                    .html\n
                    --></div>
                  ]x, $display);
}

sub make_new_page {
    my $name = shift;

    my $page = $hub->pages->new_from_name($name);

    $page->metadata->Subject($name);
    $page->metadata->update( user => $hub->current_user );
    $page->content('foo');
    $page->store( user => $hub->current_user );

    return $page;
}
