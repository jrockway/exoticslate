# @COPYRIGHT@
package Socialtext::Search::KinoSearch::Factory;
use strict;
use warnings;

use Socialtext::Search::KinoSearch::Analyzer;
use Socialtext::Search::KinoSearch::Indexer;
use Socialtext::Search::KinoSearch::Searcher;
use base 'Socialtext::Search::AbstractFactory';

# Rather than create an actual object (since there's no state), just return
# the class name.  This will continue to make all the methods below work.
sub new { $_[0] }

sub create_searcher {
    my ( $self, $ws_name, $lang ) = @_;
    return $self->_create( "Searcher", $ws_name, $lang );
}

sub create_indexer {
    my ( $self, $ws_name, $lang ) = @_;
    return $self->_create( "Indexer", $ws_name, $lang );
}

sub _create {
    my ( $self, $kind, $ws_name, $lang ) = @_;
    my $class = 'Socialtext::Search::KinoSearch::' . $kind;
    return $class->new( $ws_name, $lang, $self->_index($ws_name),
        $self->_analyzer($lang) );
}

sub _index {
    my ( $self, $ws_name ) = @_;
    return Socialtext::Paths::plugin_directory($ws_name) . '/kinosearch';
}

sub _analyzer {
    my ( $self, $lang ) = @_;
    $lang ||= 'en';
    return Socialtext::Search::KinoSearch::Analyzer->new( language => $lang );
}

1;
__END__

=pod

=head1 NAME

Socialtext::Search::KinoSearch::Factory

=head1 SEE

L<Socialtext::Search::AbstractFactory> for the interface definition.

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
