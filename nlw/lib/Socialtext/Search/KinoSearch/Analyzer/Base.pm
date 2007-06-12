# @COPYRIGHT@
package Socialtext::Search::KinoSearch::Analyzer::Base;
use strict;
use warnings;
use base 'KinoSearch::Analysis::Analyzer';

require bytes;
use Encode qw(decode_utf8 encode_utf8);
use KinoSearch::Analysis::TokenBatch;
use Lingua::Stem::Snowball qw(stemmers);

sub new {
    my ( $proto, %args ) = @_;
    my $class = ref($proto) || $proto;
    my $self = bless( \%args, $proto );
    $self->_assert_valid_language();
    return $self;
}

sub _assert_valid_language {
    my $self = shift;
    $self->{language} = 'en' unless defined $self->{language};
    unless ( grep { $self->{language} eq $_ } stemmers() ) {
        die "Invalid language: " . $self->{language} . "\n";
    }
}

sub _get_batch_from_input {
    my ( $self, $input ) = @_;
    return $input if ref $input;
    my $batch = KinoSearch::Analysis::TokenBatch->new;
    $batch->append( $input, 0, bytes::length($input) );
    return $batch;
}

1;
