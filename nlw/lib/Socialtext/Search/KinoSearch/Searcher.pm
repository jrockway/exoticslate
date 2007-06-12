# @COPYRIGHT@
package Socialtext::Search::KinoSearch::Searcher;
use strict;
use warnings;

use base 'Socialtext::Search::Searcher';
use Class::Field qw(field);
use KinoSearch::Searcher;
use Socialtext::Log qw(st_log);
use Socialtext::Search::AbstractFactory;
use Socialtext::Search::KinoSearch::Factory;
use Socialtext::Search::KinoSearch::QueryParser;
use Socialtext::Search::SimpleAttachmentHit;
use Socialtext::Search::SimplePageHit;

field 'analyzer';
field 'index';
field 'language';
field 'searcher';
field 'workspace';

sub new {
    my ( $class, $ws_name, $language, $index, $analyzer ) = @_;
    my $self = bless {}, $class;

    # Create Searcher
    $self->analyzer($analyzer);
    $self->index($index);
    $self->language($language);
    $self->workspace($ws_name);

    return $self;
}

# Perform a search and return the results.
sub search {
    my ( $self, $query_string ) = @_;
    $self->_init_searcher();
    _debug("Searching with query: $query_string");
    my $hits = $self->_search($query_string);
    return $self->_process_hits($hits);
}

# Load up the Searcher.
sub _init_searcher {
    my $self     = shift;
    my $index    = $self->index;
    my $analyzer = $self->analyzer;

    # Ensure the index exists, this creates it if it does not.
    my $factory = Socialtext::Search::AbstractFactory->GetFactory();
    $factory->create_indexer( $self->workspace, $self->language );

    $self->searcher(
        KinoSearch::Searcher->new(
            invindex => $index,
            analyzer => $analyzer,
        )
    );
    _debug( "Searcher created: index=$index analyzer=" . ref($analyzer) );
}

# Parses the query string and returns the raw KinoSearch hit results.
sub _search {
    my ( $self, $query_string ) = @_;
    my $query = $self->_parse_query($query_string);
    _debug("Performing actual search for query");
    return $self->searcher->search( query => $query );
}

# Munge the query to our liking, parse the query and return a query object.
# The default fields searched when no "field:" prefix is given on a term are
# the ones mentioned below in the "fields =>" parameter.
sub _parse_query {
    my ( $self, $query_string ) = @_;
    _debug("Parsing query");
    my $parser_class = 'Socialtext::Search::KinoSearch::QueryParser';
    return $parser_class->new( searcher => $self )->parse($query_string);
}

# Convert raw KinoSearch hits into Socialtext result objects.
sub _process_hits {
    my ( $self, $hits ) = @_;
    _debug("Processing search results");
    my @results;
    my %seen;

    $hits->seek( 0, $hits->total_hits );
    while ( my $hit = $hits->fetch_hit_hashref ) {
        next if exists $seen{ $hit->{key} };
        $seen{ $hit->{key} } = 1;
        _debug( "Contructing hit object for " . $hit->{key} );
        push @results, $self->_make_result( $hit->{key} );
    }

    return @results;
}

# Given a specific hit, convert it into a Socialtext result object.  Takes
# care to note the differences between attachments and pages.  The structure
# of the 'key' is defined in the Indexer at index time.
sub _make_result {
    my ( $self, $key ) = @_;
    my ( $page, $attachment ) = split /:/, $key, 2;
    return
        defined $attachment
        ? Socialtext::Search::SimpleAttachmentHit->new( $page, $attachment )
        : Socialtext::Search::SimplePageHit->new($page);
}

# Send a debugging message to syslog.
sub _debug {
    my $msg = shift || "(no message)";
    $msg = __PACKAGE__ . ": $msg";
    st_log->debug($msg);
}

1;
__END__

=pod

=head1 NAME

Socialtext::Search::KinoSearch::Searcher - KinoSearch grep-through-the-files Socialtext::Search::Searcher implementation.

=head1 SEE

L<Socialtext::Search::Searcher> for the interface definition.

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
