# @COPYRIGHT@
package Socialtext::Handler::Page;
use strict;
use warnings;

=head1 NAME

Socialtext::Handler::Page - A Cool URI Interface to Socialtext

=head1 SYNOPSIS

    <Location /page>
        SetHandler  perl-script
        PerlHandler +Socialtext::Handler::Page
    </Location>

=head1 DESCRIPTION

B<Socialtext::Handler::Page> is intended to be a web interface to Socialtext
using URIs that make sense, are fairly stable, and support multiple types of
output. It is NOT DONE. Initially it is being used a framework for integrating
Atom API support into Socialtext.

=head1 URIs

A URI for a page takes the form C</page/WORKSPACE/PAGE_ID>. Depending
on the incoming Accept header and the HTTP request method, different
things happen. See C<sub handler()> for now.

=cut

use base 'Socialtext::Handler::Cool';

use Socialtext::Syndicate::Atom;

sub workspace_uri_regex { qr{(?:/lite)?/page/([^/]+)/} }

sub _handle_get {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;
    return $class->_retrieve_page_content($r, $nlw);
}

sub _handle_delete {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;
    return $class->_delete_page($r, $nlw);
}

sub _handle_put {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;
    return $class->_put_page($r, $nlw);
}

sub _handle_post {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;
    return $class->_post_page($r, $nlw);
}

sub _post_page {
    my $class = shift;
    my $r = shift;
    my $nlw = shift;

    my $page = $class->_get_page($r, $nlw);
    unless ( $class->_user_has_permission( 'edit', $nlw->hub ) ) {
        return $class->_redirect_to_page( $r, $nlw, $page );
    }

    my $content_type = $r->header_in('Content-type');

    if ( !defined($page)
        and $content_type =~ /^application\/(?:x\.)?atom\+xml\b/ ) {
        return $class->_create_page_from_atom( $r, $nlw );
    }
    elsif ( defined($page)
        and $content_type eq 'application/x-www-form-urlencoded' ) {

        # XXX redirect whether we have saved or not
        # Later handle things like contention or whatever
        return $class->_edit_page_from_form( $r, $nlw, $page);
    }
    else {
        $r->status_line("400 invalid content-type $content_type in POST");
        return '', '';
    }
}

sub _redirect_to_page {
    my $class = shift;
    my $r = shift;
    my $nlw = shift;
    my $page = shift;

    $r->header_out( Location => $class->_full_uri( $r, $nlw, $page ) );
    $r->status(302);
    return '', '';
}

sub _retrieve_page_content {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;
    my $page  = $class->_get_page( $r, $nlw );

    my $accept =$r->header_in('Accept');

    my $output;
    my $type = $class->type_for_accept($accept);

    if ($page and $type eq 'application/atom+xml') {
        my $entry = Socialtext::Syndicate::Atom->new_entry;
        $output = $entry->make_entry($page, 'text')->as_xml;
    }
    elsif ($page and $type eq 'text/plain' ) {
        # XXX set some metadata in the headers
        $output = $page->content;
    }
    # default to html
    else  {
        if ( $nlw->hub->cgi->action eq 'edit' ) {
            $output = $class->_edit_action( $r, $nlw, $page );
        }
        else {
            $output = $class->_display_page( $r, $nlw, $page );
        }
    }

    # get the headers right
    # REVIEW: Would rather use direct call on $r->header_out but
    # later use of nlw->headers is getting in the way
    $nlw->hub->headers->last_modified( scalar gmtime( $page->modified_time ) );

    return $output, $type;
}

sub _edit_page_from_form {
}

sub _display_page {
}

sub _edit_action {
}

sub _recent_changes_html {
}


# REVIEW: This is not a legit url, should have protocol, host and port
sub _full_uri {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;
    my $page  = shift;
    my $workspace_name = $nlw->hub->current_workspace->name;
    return "/page/$workspace_name/" . $page->uri;
}

# REVIEW: Duplication with put_page.  Essentially the same thing except
# this doesn't want the page to exist yet.
sub _create_page_from_atom {
    my $class = shift;
    my $r = shift;
    my $nlw = shift;

    my $len = $r->header_in('Content-length');
    my $content;
    $r->read($content, $len);

    my $atom = XML::Atom::Entry->new(Stream => \$content);
    if (not defined($atom)) {
        $r->status_line('500 ' . XML::Atom::Entry->errstr);
        return '', '';
    }

    my $content_element = $atom->content;
    my $title = $atom->title;

    my $type = $content_element->type;

    if ($type eq 'text') {
        my $page = Socialtext::Page->new(
            hub => $nlw->hub,
            id  => Socialtext::Page->name_to_id($title),
        );

        # XXX is active the right thing?
        if ($page->active) {
            $r->status_line('409 entry already exists');
            return '', '';
        }

        $page = Socialtext::Page->new(hub => $nlw->hub)->create(
            title => $title,
            content => $content_element->body,
        );

        my $type = 'application/atom+xml';
        my $entry = Socialtext::Syndicate::Atom->new_entry;
        my $output = $entry->make_entry($page, 'text')->as_xml;

        $r->status( 201 );
        $r->header_out(Location => $page->page_uri);

        return $output, $type;
    }

    $r->status_line("400 invalid entry content type $type");
    return '', '';
}

sub _delete_page {
    my $class = shift;
    my $r = shift;
    my $nlw = shift;
    my $page = $class->_get_page($r, $nlw);

    unless ( $class->_user_has_permission( 'delete', $nlw->hub ) ) {
        return $class->_redirect_to_page( $r, $nlw, $page );
    }

    $page->delete( user => $nlw->hub->current_user );
    # should have some sort of okay message
    return '', '';
}

# XXX what do we do when we put a page where someone
# has changed the title, do we try to create, as in POST,
# have an error, or whut? Right now we only change content,
# no error.
sub _put_page {
    my $class = shift;
    my $r = shift;
    my $nlw = shift;
    my $page = $class->_get_page($r, $nlw);

    unless ( $class->_user_has_permission( 'edit', $nlw->hub ) ) {
        return $class->_redirect_to_page( $r, $nlw, $page );
    }

    my $len = $r->header_in('Content-length');
    my $content;
    $r->read($content, $len);

    my $atom = XML::Atom::Entry->new(Stream => \$content);
    if (not defined($atom)) {
        $r->status_line('500 ' . XML::Atom::Entry->errstr);
        return '', '';
    }

    my $content_element = $atom->content;

    my $type = $content_element->type;

    if ($type eq 'text') {
        my $page_content = $content_element->body;
        $page->content($page_content);
        $page->metadata->update;
        $page->store;
        return '', '';
    }

    $r->status_line("415 unsupported media type $type");
    return '', '';
}

sub _get_page {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;

    # REVIEW: This regexp may need some thought
    my ($page_id) = ( $r->uri =~ m{/page/[^\/]+/([^?]+)\??.*$} );
    # REVIEW: The hub+current makes the baby jesus cry
    $page_id ||= $nlw->hub->current_workspace->title;
    if ($page_id) {
        return $nlw->hub->pages->new_from_uri($page_id);
    }
    return undef;
}

1;

=head1 SEE ALSO

L<http://bitworking.org/projects/atom/draft-gregorio-09.html>,
L<http://www.xml.com/pub/a/2004/04/14/atomwiki.html>,
L<Socialtext::Handler::Page::Lite>,
L<Socialtext::Handler::Page::Full>

=cut
