# @COPYRIGHT@
package Socialtext::WikiText::Parser;
use strict;
use warnings;
use base 'WikiText::Socialtext::Parser';

# use XXX;

# my $ALPHANUM = '\p{Letter}\p{Number}\pM';

sub create_grammar {
    my $self = shift;

    my $old_grammar = $self->SUPER::create_grammar(@_);
#     my $all_blocks = $old_grammar->{_all_blocks};
#     my $all_phrases = $old_grammar->{_all_phrases};


    return {
        %$old_grammar,
    };
}

1;
