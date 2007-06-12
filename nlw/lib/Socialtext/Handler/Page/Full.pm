# @COPYRIGHT@
package Socialtext::Handler::Page::Full;
use strict;
use warnings;

use base 'Socialtext::Handler::Page';


sub _display_page {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;
    my $page  = shift;

    $nlw->hub->pages->current($page);
    return $nlw->hub->display->content_only;
#    return $nlw->hub->display->display;
}

sub _edit_action {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;
    my $page  = shift;

    $r->header_out( Location => $class->_full_uri( $r, $nlw, $page ) );
    $r->status(302);
    return '', '';
}

# XXX This is not a legit url
sub _full_uri {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;
    my $page  = shift;
    my $workspace_name = $nlw->hub->current_workspace->name;
    return "/page/$workspace_name/" . $page->uri;
}

1;
