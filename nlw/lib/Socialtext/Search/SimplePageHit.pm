# @COPYRIGHT@
use warnings;
use strict;

=head1 NAME

Socialtext::Search::SimplePageHit - A basic implementation of Socialtext::Search::PageHit.

=head1 SYNOPSIS

    $hit = Socialtext::Search::SimplePageHit->new($uri);

    $hit->page_uri(); # returns $uri

    $hit->set_page_uri('foo');

    $hit->page_uri(); # returns 'foo'


=head1 DESCRIPTION

This implementation simply stores a page URI in a blessed scalar.

=cut

package Socialtext::Search::SimplePageHit;

use base 'Socialtext::Search::PageHit';

=head1 CONSTRUCTOR

=head2 Socialtext::Search::SimplePageHit->new($page_uri)

Creates a PageHit pointing at the given URI.

=cut

sub new {
    my ( $class, $page_uri ) = @_;

    bless \$page_uri, $class;
}

=head1 OBJECT METHODS

Besides those defined in L<Socialtext::Search::PageHit>, we have

=head2 $page_hit->set_page_uri($page_uri)

Change the URI that this hit points to.

=cut

sub set_page_uri { ${$_[0]} = $_[1] }

sub page_uri { ${$_[0]} }

=head1 SEE ALSO

L<Socialtext::Search::PageHit> for the interface definition

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
