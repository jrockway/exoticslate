# @COPYRIGHT@
package Socialtext::Syndicate::Feed;
use strict;
use warnings;

use DateTime;
use DateTime::Format::W3CDTF;
use Socialtext::Timer;

our $VERSION = 0.01;

use Socialtext::Validate qw(:all :types);

sub New {
    my $class = shift;
    my %p = validate( @_, {
            title => SCALAR_TYPE,
            generator => SCALAR_TYPE,
            html_link  => URI_TYPE,
            type  => {type => SCALAR,
                      regex => qr/^(Atom|RSS20)$/ },
            pages => {type => ARRAYREF},
            contact => EMAIL_TYPE,
            feed_id => URI_TYPE,
            feed_link => URI_TYPE,
        }
    );

    my $real_class = 'Socialtext::Syndicate::' . $p{type};

    unless ( $real_class->can('_New') ) {
        eval "require $real_class";
        die "Couldn't load $real_class: $@" if $@;
    }

    delete $p{type};

    return $real_class->_New(%p);
}

sub as_xml {
    my $self = shift;
    return $self->_create_feed($self->{pages});
}

sub _generator {
    my $self = shift;
    return $self->{generator};
}

sub _contact {
    my $self = shift;
    return $self->{contact};
}

sub _author {
    my $self = shift;
    my $page = shift;
    my $user = $page->last_edited_by or return '';
    return $user->best_full_name( workspace => $page->hub->current_workspace );
}

sub _feed_id {
    my $self = shift;
    return $self->{feed_id};
}

sub _feed_title {
    die "subclass must implement";
}

sub _feed_link {
    my $self = shift;
    return $self->{feed_link};
}

sub _html_link {
    my $self = shift;
    return $self->{html_link};
}

sub _item_title {
    die "subclass must implement";
}

sub _item_description {
    die "subclass must implement";
}

sub _item_as_html {
    my $self = shift;
    my $page = shift;

    my @html_headers;
    my @html_footers;
    Socialtext::Timer->Continue('_item_as_html_html');
    my $html    = $page->to_absolute_html;
    Socialtext::Timer->Pause('_item_as_html_html');

    Socialtext::Timer->Continue('_item_as_html_creator');
    my $creator = $page->creator;
    if ($creator) {
        my $ws   = $page->hub->current_workspace;
        my $name = $creator->best_full_name( workspace => $ws );
        push @html_headers, "<div>Creator: $name</div>";
    }
    Socialtext::Timer->Pause('_item_as_html_creator');

    Socialtext::Timer->Continue('_item_as_html_tags');
    my @tags    = grep { $_ !~ /recent changes/i } $page->categories_sorted;
    if ( scalar @tags ) {
       push @html_headers, "<div>Tags: " . join( ", ", @tags ) . "</div>";
    }
    Socialtext::Timer->Pause('_item_as_html_tags');

    Socialtext::Timer->Continue('_item_as_html_attach');
    my @attachments = $page->attachments;
    if ( scalar @attachments ) {
        my @filenames
            = sort { lc($a) cmp lc($b) } map { $_->filename } @attachments;
        push @html_footers,
            "<div>Attachments: " . join( ", ", @filenames ) . "</div>";
    }
    Socialtext::Timer->Pause('_item_as_html_attach');

    return join "<hr/>", @html_headers, $html, @html_footers;
}

sub _cdata {
    my $self = shift;
    my $data = shift;
    return '<![CDATA[' . $data . ']]>';
}

sub _make_w3cdtf {
    my $self = shift;
    my $epoch = shift;
    my $dt = DateTime->from_epoch( epoch => $epoch );
    return DateTime::Format::W3CDTF->new->format_datetime($dt);
}

1;

__END__

=head1 NAME

Socialtext::Syndicate::Feed - Syndication feeds for Socialtext pages

=head1 SYNOPSIS

    use Socialtext::Syndicate::Feed

    my $feed = Socialtext::Syndicate::Feed->New(
        title => 'my fancy feed',
        link  => 'http://example.com/index.html',
        type  => 'Atom',
        pages => \@pages,
        contact => 'foo@example.com',
        generator => 'Socialtext Thing',
    );
    print $feed->as_xml;

=head1 DESCRIPTION

This module provides an interface to creating Atom or RSS20 syndication
feeds of a collection of L<Socialtext::Page> objects. It makes no assumptions
about the pages, so this can be used to syndicate recent changes, a weblog,
the result of a search query, a single page, or whatever else you 
might imagine.

=head1 METHODS

=over 4

=item New

Returns a Socialtext::Syndicate::Feed subclass based on the type parameter.
Takes multiple required parameters:

=over 8

=item type

Either "RSS20" or "Atom". The type of feed being created.

=item title

The title that will be used with the feed.

=item link

A link to the home URL of the feed. This is the place an aggregator will be
sent to when it choose to go to the home page of the feed.

=item pages

A reference to an array of L<Socialtext::Page> objects.

=item contact

A string representing an email address. Required for valid syndication feeds.

=back

=item as_xml

Output the created feed as Atom or RSS20 type XML.

=back

=head1 AUTHOR

Socialtext, C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2005 Socialtext, Inc. All Rights Reserved.

=cut

