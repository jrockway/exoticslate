package Socialtext::Handler::Tag;
# @COPYRIGHT@

use strict;
use warnings;

use base 'Socialtext::Handler::Cool';
use YAML;
use JSON;
use Socialtext::TT2::Renderer;
use Socialtext::String;
use DateTime;
use DateTime::Format::Strptime;
use URI::Escape;

$JSON::UTF8 = 1;

sub workspace_uri_regex { qr{(?:/lite)?/page/([^/]+)/} }

sub _handle_put {
    my $self = shift;
    my $r     = shift;
    my $nlw   = shift;

    my $page = $self->_get_page($r, $nlw);

    if (!defined($page)) {
        $r->status_line('404 page does not exist');
        return '', '';
    }

    return $self->_add_tag($r, $nlw, $page);
}

*_handle_post = \&_handle_put; # same functionality

sub _handle_delete {
    my $self = shift;
    my $r     = shift;
    my $nlw   = shift;

    my $page = $self->_get_page($r, $nlw);

    if (!defined($page)) {
        $r->status_line('404 page does not exist');
        return '', '';
    }

    unless ( $self->_user_has_permission( 'edit', $nlw->hub ) ) {
        # REVIEW: Probably wrong status to send
        $r->status_line("400 insufficient permission to edit to this page");
        return '', '';
    }

    return $self->_delete_tag($r, $nlw, $page);
}

sub _handle_get {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;

    my $page = $class->_get_page($r, $nlw);

    if (!defined($page)) {
        $r->status_line('404 page does not exist');
        return '', '';
    }

    unless ( $class->_user_has_permission( 'read', $nlw->hub ) ) {
        # REVIEW: Probably wrong status to send
        $r->status_line("400 insufficient permission to attach to this page");
        return '', '';
    }

    return $class->_get_listing($r, $nlw, $page);
}

sub _add_tag {
    my $self = shift;
    my $r = shift;
    my $nlw = shift;
    my $page = shift;

    my $tagName = $self->_retrieve_tag_name($r);

    if (!$page->has_tag($tagName)) {
        $page->metadata->update(user => $nlw->hub->current_user);
        $page->add_tags($tagName);
    }

    $r->status_line("201 Tag $tagName added");

    return $self->_get_listing($r, $nlw, $page);
}

sub _delete_tag {
    my $self = shift;
    my $r = shift;
    my $nlw = shift;
    my $page = shift;

    my $tagName = $self->_retrieve_tag_name($r);
    my $metadata = $page->metadata;
    if ($metadata->has_category($tagName)) {
        $page->delete_tag($tagName);
        $page->metadata->update(user => $nlw->hub->current_user);
        $page->store( user => $nlw->hub->current_user );
    }
    else {
        $r->status_line("404 Tag not assigned to page");
    }

    return $self->_get_listing($r, $nlw, $page);
}

sub _retrieve_tag_name {
    my ($self, $r) = @_;

    my @parts = $r->uri =~ $self->_uri_parts_regex;

    return uri_unescape($parts[2]);
}

sub _get_listing {
    my $self = shift;
    my $r = shift;
    my $nlw = shift;
    my $page = shift;

    my $accept = $r->header_in('Accept');

    my %tags = $nlw->hub->category->weight_categories(
        @{ $page->metadata->Category } );

    if (defined($accept) && $accept =~ m[\btext/javascript\b]) {
        return $self->_get_listing_json($r, $nlw, \%tags);
    } else {
        return $self->_get_listing_text($r, $nlw, \%tags);
    }
}

sub _get_listing_json {
    my $self = shift;
    my $r = shift;
    my $nlw = shift;
    my $TAGS = shift;

    my $text = '';
    {
        local $JSON::AUTOCONVERT = 0;
        local $JSON::SingleQuote = 0;
        my $json = JSON->new(autoconv => 0, singlequote => 0);
        foreach my $tag (@{$TAGS->{tags}}) {
             $tag->{count} = JSON::Number($tag->{count});
             $tag->{tag} = Socialtext::String::uri_escape($tag->{tag});
        }
        $TAGS->{maxCount} = JSON::Number($TAGS->{maxCount});

        $text = $json->objToJson($TAGS);
    }
    
    return ($text, 'text/javascript');
}

sub _get_listing_text {
    my $self = shift;
    my $r = shift;
    my $nlw = shift;
    my $TAGS = shift;

    my $text='';
    foreach (@{$TAGS->{tags}}) {
        $text .= $_->{tag}."\n";
    }
    return $text, 'text/plain';
}

sub _get_page {
    my $class = shift;
    my $r     = shift;
    my $nlw   = shift;

    # REVIEW: This regexp may need some thought
    my ($workspace_id, $page_id) = ( $r->uri =~ m{/page/([^\/]+)/([^?/]+)\??.*$} );
    # REVIEW: The hub+current makes the baby jesus cry
    $page_id ||= $nlw->hub->current_workspace->title;
    if ($page_id) {
        # This little game is to avoid weirdnesses in page->title
        my $id = $nlw->uri_unescape($page_id);
        if (!$nlw->hub->pages->page_exists_in_workspace($id,$workspace_id)) {
            return undef;
        }
        my $page = Socialtext::Page->new(
            hub => $nlw->hub,
            id  => Socialtext::Page->name_to_id($id),
        );
        my $return_id = Socialtext::Page->name_to_id($page->title);

        $page->title( $id )
            unless $return_id eq $page_id;
        $page->load;
        return $page;
    }
    return undef;
}


=head2 _uri_parts_regex

Given a URI for requesting a particular tag:

  my ($workspace_id, $page_id, $tag)
    = $r->uri =~ $class->_uri_parts_regex;

Given a URI for requesting the tag list, or adding a tag to the pool:

  my ($workspace_id, $page_id)
    = $r->uri =~ $class->_uri_parts_regex;

=cut

sub _uri_parts_regex {
    # Example: /page/corp/baseball/tags
    #          /page/corp/baseball/tags/Help
    qr|
        /page/
        ([^/]+)      # workspace id
        /
        ([^/]+)      # page id
        /
        tags
        (?:
            /
            (.+)
        )?
    |x
}

1;

__END__

=head1 NAME

Socialtext::Handler::Tag - A Cool URI Interface to Socialtext Page Tags

=head1 SYNOPSIS

    PerlModule  Socialtext::Handler::Tag
    <Location /page/*/*/tags>
        SetHandler  perl-script
        PerlHandler Socialtext::Handler::Tag
    </Location>

=head1 DESCRIPTION

B<Socialtext::Handler::Tag> is an interface to Socialtext's page tag feature using more traditional URIs, and taking advantage of the HTTP protocol in a RESTful way.

=head1 URIs

The URI for a tag is
C</page/workspace/page_id/tags/tag>. You can C<GET>
tags from that URI. The URI for listing tags on a page is
C</page/workspace/page_id/tags>. You can C<GET> a list of information
about attachments on the page in JSON serialized format by specifying that you
Accept C<text/json> in the request header.

=head1 SEE ALSO

L<Socialtext::Handler::Cool>, L<Socialtext::Handler::Page>

=cut
