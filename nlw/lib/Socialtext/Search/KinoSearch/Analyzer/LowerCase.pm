# @COPYRIGHT@
package Socialtext::Search::KinoSearch::Analyzer::LowerCase;
use strict;
use warnings;
use base 'Socialtext::Search::KinoSearch::Analyzer::Base';

use Encode qw(decode_utf8 encode_utf8);

sub analyze {
    my ( $self, $batch ) = @_;
    $batch = $self->_get_batch_from_input($batch);

    while ( $batch->next ) {
        my $text = lc( decode_utf8( $batch->get_text ) );
        $batch->set_text( encode_utf8($text) );
    }
    $batch->reset;

    return $batch;
}

1;
