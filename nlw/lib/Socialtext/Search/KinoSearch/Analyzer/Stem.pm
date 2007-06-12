# @COPYRIGHT@
package Socialtext::Search::KinoSearch::Analyzer::Stem;
use strict;
use warnings;
use base 'Socialtext::Search::KinoSearch::Analyzer::Base';

use Encode qw(decode_utf8 encode_utf8);
use Lingua::Stem::Snowball qw(stemmers);

sub analyze {
    my ( $self, $batch ) = @_;
    $batch = $self->_get_batch_from_input($batch);
    my $stemmer = Lingua::Stem::Snowball->new(
        lang     => $self->{language},
        encoding => 'UTF-8'
    );

    my $all_texts = $batch->get_all_texts;
    $all_texts = [ map decode_utf8($_), @$all_texts ];
    $stemmer->stem_in_place($all_texts);
    $all_texts = [ map encode_utf8($_), @$all_texts ];
    $batch->set_all_texts($all_texts);

    return $batch;
}

1;
