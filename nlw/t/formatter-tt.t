#!perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext tests => 3;
fixtures( 'admin' );

my $hub = new_hub('admin');

{
    my $content = "`++\$bar`\n";
    my $page = make_new_page("Formatter Test for tt wafl");
    isa_ok( $page, 'Socialtext::Page' );

    $page->content($content);
    my $html = $page->to_html;
    like $html, qr/<tt>\+\+\$bar<\/tt>/, $content;
}

sub make_new_page {
    my $name = shift;

    my $page = $hub->pages->new_from_name($name);
    isa_ok( $page, 'Socialtext::Page' );

    $page->metadata->Subject($name);
    $page->metadata->update( user => $hub->current_user );
    $page->content('foo');
    $page->store( user => $hub->current_user );

    return $page;
}
