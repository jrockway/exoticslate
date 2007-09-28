# @COPYRIGHT@
use warnings;
use strict;

=head1 NAME

Socialtext::Search::SimplePageHit - A basic implementation of Socialtext::Search::PageHit.

=head1 SYNOPSIS

    $hit = Socialtext::Search::SimplePageHit->new($uri, $workspace_name, $key);

    $hit->page_uri(); # returns $uri

    $hit->set_page_uri('foo');

    $hit->page_uri(); # returns 'foo'

    $hit->key(); # returns page's key


=head1 DESCRIPTION

This implementation simply stores a page URI in a blessed scalar.

=cut

package Socialtext::Search::SimplePageHit;

use base 'Socialtext::Search::PageHit';

=head1 CONSTRUCTOR

=head2 Socialtext::Search::SimplePageHit->new($page_uri, $workspace_name, $key)

Creates a PageHit pointing at the given URI.

=cut

sub new {
    my ( $class, $page_uri, $workspace_name, $key ) = @_;

    bless {
        page_uri       => $page_uri,
        workspace_name => $workspace_name,
        key            => $key,
    }, $class;
}

=head1 OBJECT METHODS

Besides those defined in L<Socialtext::Search::PageHit>, we have

=head2 $page_hit->set_page_uri($page_uri)

Change the URI that this hit points to.

=cut

sub set_page_uri { $_[0]->{page_uri} = $_[1] }
sub page_uri { $_[0]->{page_uri} }

=head2 $page_hit->set_workspace_name($workspace_name);

Change the workspace that this hit points to.

=cut

sub set_workspace_name { $_[0]->{workspace_name} = $_[1] }
sub workspace_name     { $_[0]->{workspace_name} }

=head2 $page_hit->set_key($key)

Change the index document key that this hit points to.

=cut

sub set_key { $_[0]->{key} = $_[1] }
sub key     { $_[0]->{key} }

=head2 $page_hit->composed_key()

Compose a key suitable for cross-workspace uniqueness.

=cut

sub composed_key     {
    my $self = shift;
    my $workspace_name = $self->workspace_name;
    my $key = $self->key;
    return "$workspace_name $key";
}

1;

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
