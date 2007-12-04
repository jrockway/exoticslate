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
use Socialtext::Search::Utils;

field 'analyzer';
field 'config';
field 'index';
field 'searcher';
field 'ws_name';
field 'language';

sub new {
    my ( $class, $ws_name, $language, $index, $analyzer, $config ) = @_;
    my $self = bless {}, $class;

    # Create Searcher
    $self->analyzer($analyzer);
    $self->index($index);
    $self->language($language);
    $self->ws_name($ws_name);
    $self->config($config);

    return $self;
}

# Perform a search and return the results.
sub search {
    my ( $self, $query_string, $authorizer ) = @_;
    $self->_init_searcher();
    _debug("Searching with query: $query_string");
    my $hits = $self->_search( $query_string, $authorizer );
    my $hits_processor_method = $self->config->hits_processor_method;
    return $self->$hits_processor_method($hits);
}

# Load up the Searcher.
sub _init_searcher {
    my $self     = shift;
    my $index    = $self->index;
    my $analyzer = $self->analyzer;

    # Ensure the index exists, this creates it if it does not.
    my $factory = Socialtext::Search::AbstractFactory->GetFactory();
    $factory->create_indexer( $self->ws_name );

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
    my ( $self, $query_string, $authorizer ) = @_;
    my $query_parser_method = $self->config->query_parser_method;
    my $query = $self->$query_parser_method($query_string);
    $self->_authorize( $query, $authorizer );
    _debug("Performing actual search for query");
    return $self->searcher->search( query => $query );
}

# Either do nothing if the query's authorized, or throw NoSuchWorkspace or
# Auth.
sub _authorize {
    my ( $self, $query, $authorizer ) = @_;

    return unless defined $authorizer;

    Socialtext::Exception::Auth->throw
        unless $authorizer->( $self->ws_name );
}

# Munge the query to our liking, parse the query and return a query object.
# The default fields searched when no "field:" prefix is given on a term are
# the ones mentioned below in the "fields =>" parameter.
sub _parse_query {
    my ( $self, $query_string ) = @_;
    _debug("Parsing query using _parse_query()" );
    my $parser_class = 'Socialtext::Search::KinoSearch::QueryParser';
    return $parser_class->new( searcher => $self )->parse($query_string);
}

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
        push @results, $self->_make_result( $hit->{key}, $self->ws_name );
    }

    return @results;
}

sub _make_result {
    my ( $self, $key, $ws_name ) = @_;
    my ( $page, $attachment ) = split /:/, $key, 2;
    return
        defined $attachment
        ? Socialtext::Search::SimpleAttachmentHit->new( $page, $attachment, $ws_name, $key )
        : Socialtext::Search::SimplePageHit->new( $page, $ws_name, $key );
}

# Send a debugging message to syslog.
sub _debug {
    my $msg = shift || "(no message)";
    $msg = __PACKAGE__ . ": $msg";
    st_log->debug($msg);
}

1;

=head1 NAME

Socialtext::Search::KinoSearch::Searcher
- KinoSearch Socialtext::Search::Searcher implementation.

=head1 SEE

L<Socialtext::Search::Searcher> for the interface definition.

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
