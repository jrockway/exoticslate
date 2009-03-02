# @COPYRIGHT@
package Socialtext::Search::KinoSearch::QueryParser;
use strict;
use warnings;

require bytes;
use Data::UUID;
use Encode qw(encode_utf8);
use KinoSearch::Index::IndexReader;
use KinoSearch::QueryParser::QueryParser;
use KinoSearch::Search::BooleanQuery;
use KinoSearch::Search::TermQuery;
use KinoSearch::Store::RAMInvIndex;
use Socialtext::Search::Utils;

sub new {
    my ( $class, %args ) = @_;
    return bless( \%args, $class );
}

sub parse {
    my ( $self, $query_string ) = @_;

    # Fix the raw query string.  Mostly manipulating "field:"-like strings.
    $query_string = $self->munge_raw_query_string($query_string);

    # Preprocess the query to clearly mark wildcards out of the way.
    $self->_replace_wildcards( \$query_string );

    # Make workspace field searches hardened against stemming
    $self->_harden_workspace( \$query_string );

    # Get the default query tree from the query string.
    my $query = KinoSearch::QueryParser::QueryParser->new(
        analyzer => $self->{searcher}->analyzer,
        fields   => [qw(title text)]
        , # Default fields to be searched. XXX: Some day, someone's gonna want to include docs that are tagged with the search term by default. When they do, add 'tag' to the list and voila. --zbir
        default_boolop => 'AND',
    )->parse($query_string);

    # Postprocess the query string to expand wildcards
    return $self->_expand_wildcards($query);
}

# Raw text manipulations like this are not 100% safe to do, but should be okay
# considering their esoteric nature (i.e. dealing w/ fields).
sub munge_raw_query_string {
    my ( $self, $query ) = @_;

    # Establish some field synonyms.
    $query =~ s/=/title:/g;        # Old style title search
    $query =~ s/category:/tag:/gi; # Old name for tags
    $query =~ s/tag:\s+/tag:/gi;   # fix capitalization and allow an extra space

    # Find everything that looks like a field, but is not.  I.e. in "cow:foo"
    # we would find "cow:". 
    #
    # XXX: Fields duplicated here and Socialtext/Search/KinoSearch/Indexer.
    my @fields = qw(key title tag text);
    my @non_fields;
    while ( $query =~ /(\w+):/g ) {
        my $maybe_field = $1;
        push @non_fields, $maybe_field
            unless grep { $_ eq $maybe_field } @fields;
    }

    # If it looks like a field but is not then remove the ":".  This prevents
    # things being treated as fields when they are not fields.
    for my $non_field (@non_fields) {
        $non_field = quotemeta $non_field;
        $query =~ s/(${non_field}):/$1 /g;
    }

    return $query;
}

sub _harden_workspace {
    my ( $self, $query_string_ref ) = @_;

    # The only way I could find to do this was with a zero-width
    # positive look-behind assertion.  Not sure how expensive it is...
    $$query_string_ref =~ 
        s{(?<=workspace\:)([\w\-]+)}
         {&Socialtext::Search::Utils::harden($1)}eg;
}

sub _replace_wildcards {
    my ( $self, $query_string_ref ) = @_;
    my $uuid_gen = Data::UUID->new;
    my %wildcards;

    while ( $$query_string_ref =~ /(?:^|\W)(\w+)\*/g ) {
        my $pat  = $1;

        # For performance reasons, do not support less than 3 chars.
        next if length($pat) < 3; 

        # Add 0 to UUID so it does not get stemed.  For example, if UUID ends
        # in "fe" it will get stemmed to just ending in "f".
        my $uuid = lc $uuid_gen->create_hex . "0"; 
        $wildcards{$uuid} = lc($pat);

        $$query_string_ref =~ s/(^|\W)\Q$pat\E\*/$1$uuid/g;
    }

    $self->{wildcards} = \%wildcards;
}

# Given a wildcard and a field for the resulting TermQueries (taken from the
# TermQuery we are replacing), return a BooleanQuery corresponding to the
# expansion of the given wildcard.
sub _expand_wildcards {
    my ( $self, $query ) = @_;
    for my $c ( @{ $query->{clauses} } ) {
        $c->{query} = $self->_expand_wildcards( $c->{query} );
    }
    $self->_fill_in_wildcard($query);
}

sub _fill_in_wildcard {
    my ( $self, $query ) = @_;
    return $query unless $query->isa('KinoSearch::Search::TermQuery');

    my $text     = $query->{term}->{text};
    my $field    = $query->{term}->{field};
    my $wildcard = $self->{wildcards}->{$text};
    if ( defined $wildcard ) {
        return $self->_boolean_for_wildcard( $field, $wildcard );
    }

    return $query;
}

# Given a wildcard and a field for the resulting TermQueries (taken from the
# TermQuery we are replacing), return a BooleanQuery corresponding to the
# expansion of the given wildcard.
sub _boolean_for_wildcard {
    my ( $self, $field, $wildcard ) = @_;
    my $expansions = $self->_wildcard_expansions( $field, $wildcard );
    my $bool_query = KinoSearch::Search::BooleanQuery->new(
        max_clause_count => ~0,  # ~0 is MAX_INT
    );

    for my $term (@$expansions) {
        my $term_query = KinoSearch::Search::TermQuery->new( term => $term );
        $bool_query->add_clause( query => $term_query, occur => 'SHOULD' );
    }

    return $bool_query;
}

sub _wildcard_expansions {
    my ( $self, $wc_field, $wc ) = @_;
    my ( @matches, @terms );
    my $key            = "_wce_cache_${wc_field}:$wc";
    my $wc_bytes       = encode_utf8($wc);
    my $wc_field_bytes = encode_utf8($wc_field);

    return $self->{$key} if exists $self->{$key};

    $self->_forall_terms(sub {
        my $term = shift;
        push @terms, $term unless exists $self->{_cached_terms};
        return unless $term->get_field eq $wc_field_bytes;
        unless ( bytes::index( $term->get_text, $wc_bytes ) ) {
            push @matches, $term;
        }
    });

    $self->{$key} = \@matches;
}

sub _forall_terms {
    my ( $self, $hook ) = @_;
    if ( exists $self->{_cached_terms} ) {
        for my $term ( @{ $self->{_cached_terms} } ) {
            $hook->($term);
        }
    }
    else {
        my @terms;
        for my $reader ( $self->_segment_readers ) {
            my $terms = $reader->terms;
            while ( $terms->next ) {
                my $term = $terms->get_term;
                push @terms, $term;
                $hook->($term);
            }
        }
        $self->{_cached_terms} = \@terms;
    }
}

# When we create an IndexReader we either get a single SegReader, if we have
# one segment, or a MultiReader which contains multiple SegReaders for each
# segment.  I'm not sure why you just don't always get a MultiReader.
sub _segment_readers {
    my $self   = shift;
    my $index = KinoSearch::Store::RAMInvIndex->new(
        path => $self->{searcher}->index() );
    my $reader = KinoSearch::Index::IndexReader->new( invindex => $index );
    if ( $reader->isa('KinoSearch::Index::MultiReader') ) {
        return @{ $reader->{sub_readers} };
    }
    return $reader;
}

1;
