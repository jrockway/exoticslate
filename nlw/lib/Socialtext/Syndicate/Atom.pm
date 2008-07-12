# @COPYRIGHT@
package Socialtext::Syndicate::Atom;

use strict;
use warnings;

use base 'Socialtext::Syndicate::Feed';

use Encode;
use XML::Atom::Feed;
use XML::Atom::Entry;
use XML::Atom::Person;
use XML::Atom::Content;
use Readonly;

$XML::Atom::DefaultVersion = "1.0";

sub _New {
    my $class = shift;
    my %p     = @_;
    return bless \%p, $class;
}

# XXX used for atom api, not yet implemented
#sub new_entry {
#    my $class = shift;
#    my %p     = ();
#    return bless \%p, $class;
#}

sub make_entry {
    my $self = shift;
    my $page   = shift;
    my $format = shift;
    $format ||= 'html';

    my $entry = XML::Atom::Entry->new();
    $entry->title( $page->title );

    # XXX full_uri fails on pages that have InterWikiLinks
    # possible scoping issue
    $entry->add_link(
        $self->_make_link(
            url  => $page->full_uri,
            type => 'text/html',
            rel  => 'alternate'
        )
    );
    if ( $format eq 'html' ) {
        $entry->content( $self->_content( $self->_item_as_html($page) ) );
    }
    elsif ( $format eq 'text' ) {
        $entry->content( $self->_content( $page->content ) );
    }
    else {
        die "unknown format for entry content";
    }

    # XXX id and link shouldn't necessarily be the same
    # XXX consider tag: for id
    $entry->id( $page->full_uri );
    $entry->author( $self->_author($page) );
    $entry->updated( $self->_make_w3cdtf( $page->modified_time ) );
    $entry->categories( $self->atom_categories($page) );
    return $entry;
}

sub atom_categories {
    my ( $self, $page ) = @_;
    my @categories;
    my @tags = grep { $_ !~ /recent changes/i } $page->categories_sorted;
    for my $tag (@tags) {
        my $category = XML::Atom::Category->new;
        $category->term($tag);
        $category->label($tag);
        push @categories, $category;
    }
    return @categories;
}

sub _create_feed {
    my $self = shift;
    my $pages = shift;

    my $atom = XML::Atom::Feed->new();

    $atom->title( $self->_feed_title );
    $atom->id( $self->_feed_id );
    $atom->add_link(
        $self->_make_link(
            url  => $self->_html_link,
            type => 'text/html',
            rel  => 'alternate',
        )
    );
    $atom->add_link(
        $self->_make_link(
            url  => $self->_feed_link,
            type => 'application/atom+xml',
            rel  => 'self',
        )
    );

    # XXX implement this, _post_link undefined
    # XXX for atomapi
#    $atom->add_link(
#        $self->_make_link(
#            url  => $self->_post_link,
#            type => 'application/atom+xml',
#            rel  => 'service.post',
#        )
#    );

    # XXX extract
    my $modified_time = 0;
    foreach my $page (@$pages) {
        $modified_time = $page->modified_time
          if ( $page->modified_time > $modified_time );
    }
    $modified_time ||= time();
    $atom->updated( $self->_make_w3cdtf($modified_time) );

    foreach my $page (@$pages) {
        my $entry = $self->make_entry($page);
        $atom->add_entry($entry);
    }

    return $atom->as_xml;
}

# IE6 will do display the content if we use this content-type, whereas
# if we use application/rss+xml it prompts the user asking what to do
# with the file.
sub content_type { 'application/xml; charset=utf-8' }

sub _content {
    my $self         = shift;
    my $content_body = shift;

    my $content = XML::Atom::Content->new();
    $content->body($content_body);

    return $content;
}

sub _make_link {
    my $self = shift;
    my %p    = @_;
    my $link = XML::Atom::Link->new();
    $link->type( $p{type} );
    $link->rel( $p{rel} );
    $link->href( $p{url} );

    return $link;
}

sub _author {
    my $self = shift;
    my $name   = $self->SUPER::_author(@_);
    my $author = XML::Atom::Person->new();
    $author->name($name);

    return $author;
}

sub _feed_title {
    my $self = shift;
    return $self->{title};
}

1;

__END__

=head1 NAME

Socialtext::Syndicate::Atom - Atom feeds for Socialtext pages

=head1 SYNOPSIS

Do not use this class directly. See L<Socialtext::Syndication::Feed>
which acts a factory.
    
=head1 METHODS

This class has no public methods.

=head1 AUTHOR

Socialtext, C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2005 Socialtext, Inc. All Rights Reserved.

=cut

