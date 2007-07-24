# @COPYRIGHT@
package Socialtext::Handler::Page::Lite;
use strict;
use warnings;

use base 'Socialtext::Handler::Page';

use Socialtext::Lite;

sub _edit_page_from_form {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;
    my $page  = shift;

    my $apr   = Apache::Request->instance( $r );

    # XXX this probably needs some error handling...
    # XXX name the parameters
    my $html = Socialtext::Lite->new( hub => $nlw->hub )->edit_save(
        page        => $page,
        content     => $apr->param('page_body') || '',
        revision_id => $apr->param('revision_id') || '',
        revision    => $apr->param('revision') || '',
        subject     => $apr->param('subject') || '',
    );

    # $html contains contention info
    if (length($html)) {
        return $html, 'text/html';
    }
    else {
        $r->header_out( Location => $class->_full_uri( $r, $nlw, $page ) );
        $r->status(302);
        return '', '';
    }
}

# XXX This is not a legit url
sub _full_uri {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;
    my $page  = shift;
    my $workspace_name = $nlw->hub->current_workspace->name;
    return "/lite/page/$workspace_name/" . $page->uri;
}

sub _display_page {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;
    my $page  = shift;
    return Socialtext::Lite->new( hub => $nlw->hub )->display($page);
}

sub _edit_action {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;
    my $page  = shift;

    unless ( $class->_user_has_permission( 'edit', $nlw->hub ) ) {
        return $class->_redirect_to_page( $r, $nlw, $page );
    }

    return Socialtext::Lite->new( hub => $nlw->hub )->edit_action($page);
}

sub _recent_changes_html {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;
    return Socialtext::Lite->new( hub => $nlw->hub )->recent_changes;
}

1;

__END__

=head1 NAME

Socialtext::Handler::Page::Lite - A Cool URI Interface to NLW with a minimal interface

=head1 SYNOPSIS

    <Location /lite/page>
        SetHandler  perl-script
        PerlHandler +Socialtext::Handler::Page::Lite
    </Location>

=head1 DESCRIPTION

=head1 URIs

A URI for a page takes the form C</lite/page/workspace/page_id>.

=cut

