# @COPYRIGHT@
package Socialtext::Search::KinoSearch::Analyzer;
use strict;
use warnings;
use base 'Socialtext::Search::KinoSearch::Analyzer::Base';

use Socialtext::Search::KinoSearch::Analyzer::LowerCase;
use Socialtext::Search::KinoSearch::Analyzer::Stem;
use Socialtext::Search::KinoSearch::Analyzer::Tokenize;

sub analyze {
    my ( $self, $input ) = @_;
    my $batch = $self->_get_batch_from_input($input);
    for my $type (qw(LowerCase Tokenize Stem)) {
        my $class = "Socialtext::Search::KinoSearch::Analyzer::$type";
        my $analyzer = $class->new( language => $self->{language} );
        $batch = $analyzer->analyze($batch);
    }
    return $batch;
}

1;
