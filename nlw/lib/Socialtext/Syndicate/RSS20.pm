# @COPYRIGHT@
package Socialtext::Syndicate::RSS20;
use strict;
use warnings;

use base 'Socialtext::Syndicate::Feed';

use XML::RSS;
use DateTime;
use DateTime::Format::Mail;

sub _New {
    my $class = shift;
    my %p     = @_;
    return bless \%p, $class;
}

sub _create_feed {
    my $self = shift;
    my $pages = shift;

    my $rss = new XML::RSS( version => '2.0' );

    my $feed_modified = 0;
    foreach my $page (@$pages) {
        my $pub_date = $page->modified_time;
        $feed_modified = $pub_date if $pub_date > $feed_modified;
        $rss->add_item(
            title       => $self->_item_title($page),
            link        => $page->full_uri,
            permaLink   => $page->full_uri,
            description => $self->_item_description($page),
            author      => $self->_author($page),
            pubDate     => $self->_format_date($pub_date),
        );
    }

    $rss->channel(
        title     => $self->_feed_title,
        link      => $self->_html_link,
        webMaster => $self->_contact,
        generator => $self->_generator,
        pubDate   => $self->_format_date($feed_modified),
    );

    return $rss->as_string;
}

# IE6 will do display the content if we use this content-type, whereas
# if we use application/rss+xml it prompts the user asking what to do
# with the file.
sub content_type { 'application/xml; charset=utf-8' }

sub _format_date {
    my $self = shift;
    my $epoch_time = shift;
    my $dt = DateTime->from_epoch( epoch => $epoch_time );
    return DateTime::Format::Mail->format_datetime($dt);
}

sub _feed_title {
    my $self = shift;
    return $self->_cdata( $self->{title} );
}

sub _item_title {
    my $self = shift;
    my $page = shift;
    return $self->_cdata( $page->metadata->Subject );
}

sub _item_description {
    my $self = shift;
    my $page = shift;
    my $html = $page->to_absolute_html;
    return $self->_cdata($html);
}

1;

__END__

=head1 NAME

Socialtext::Syndicate::RSS20 - RSS20 feeds for Socialtext pages

=head1 SYNOPSIS

Do not use this class directly. See L<Socialtext::Syndicate::Feed>
which acts a factory.
    
=head1 METHODS

This class has no public methods.

=head1 AUTHOR

Socialtext, C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2005 Socialtext, Inc. All Rights Reserved.

=cut

