# @COPYRIGHT@
package Socialtext::Search::KinoSearch::Analyzer::Base;
use strict;
use warnings;
use base 'KinoSearch::Analysis::Analyzer';

require bytes;
use KinoSearch::Analysis::TokenBatch;

sub new {
    my ( $proto, %args ) = @_;
    my $class = ref($proto) || $proto;
    my $self = bless( \%args, $proto );
    return $self;
}

sub _get_batch_from_input {
    my ( $self, $input ) = @_;
    return $input if ref $input;
    my $batch = KinoSearch::Analysis::TokenBatch->new;
    $batch->append( $input, 0, bytes::length($input) );
    return $batch;
}

1;
