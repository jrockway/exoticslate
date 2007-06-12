# @COPYRIGHT@
use warnings;
use strict;

package Socialtext::Search::AbstractFactory;

use Carp 'croak';
use Socialtext::AppConfig;

=head1 NAME

Socialtext::Search::AbstractFactory - Instantiate search-related objects.

=head1 SYNOPSIS

    $factory = Socialtext::Search::AbstractFactory->GetFactory();
    $indexer = create_indexer($workspace_name);
    # Index documents in this workspace using $indexer.

    $searcher = create_searcher($workspace_name);
    # Perform searches on this workspace using $searcher.

=head1 DESCRIPTION

C<Socialtext::Search::AbstractFactory> defines an object interface for search
factories.  A factory is simply a class which understands how to instantiate
sets of related objects.  In this case, those related objects are searchers
and indexers.

With this interface, fulltext search systems become interchangeable, and the
calling classes need not know which implementation is in use.  A call to
L</GetFactory> produces the correct factory, and that factory can produce
searcher and indexer objects which operate on the current fulltext search
implementation.

Switching between fulltext search implementations is accomplished by setting
L<Socialtext::AppConfig/search_factory_class>.

=head1 CLASS METHODS

=head2 GetFactory()

Returns an instance of the class configured in
L<Socialtext::AppConfig/search_factory_class>, by C<require>ing and calling C<new()>
on this class.  If there are troubles loading or instantiating, the method
will C<die> with a string beginning
C<< Socialtext::Search::AbstractFactory->GetFactory: >>.

=cut

sub GetFactory {
    my ( $class ) = @_;

    my $factory_class = Socialtext::AppConfig->search_factory_class;

    eval "require $factory_class";
    die __PACKAGE__, "->GetFactory: $@" if $@;

    my $factory = $factory_class->new
        or die __PACKAGE__, "->GetFactory: $factory_class->new returned null";

    return $factory;
}

=head1 OBJECT INTERFACE

=head2 $factory->create_searcher($workspace_name)

Returns an implementation of the L<Socialtext::Search::Searcher> interface which will
search the given workspace.

=cut

sub create_searcher {
    my ( $self ) = @_;

    if (ref $self) {
        croak(ref $self, ": internal bug: create_searcher not implemented");
    }
    else {
        croak(__PACKAGE__, "::create_searcher called in a weird way");
    }
}

=head2 $factory->create_indexer($workspace_name)

Returns an implementation of the L<Socialtext::Search::Indexer> interface which will
search the given workspace.

=cut

sub create_indexer {
    my ( $self ) = @_;

    if (ref $self) {
        croak(ref $self, ": internal bug: create_indexer not implemented");
    }
    else {
        croak(__PACKAGE__, "::create_indexer called in a weird way");
    }
}

=head1 SEE ALSO

L<Socialtext::AppConfig>, L<http://en.wikipedia.org/wiki/Abstract_factory_pattern>

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

