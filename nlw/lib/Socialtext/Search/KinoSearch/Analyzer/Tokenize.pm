# @COPYRIGHT@
package Socialtext::Search::KinoSearch::Analyzer::Tokenize;
use strict;
use warnings;
use base 'Socialtext::Search::KinoSearch::Analyzer::Base';

require bytes;
use Encode qw(decode_utf8 encode_utf8);
use KinoSearch::Analysis::TokenBatch;

sub analyze {
    my ( $self, $batch ) = @_;
    $batch = $self->_get_batch_from_input($batch);
    my $new_batch    = KinoSearch::Analysis::TokenBatch->new;
    my $token_rx     = $self->_get_token_rx;
    my $separator_rx = $self->_get_token_seperator_rx;

    # alias input to $_
    while ( $batch->next ) {
        local $_ = decode_utf8( $batch->get_text );
        pos = 0;

        # accumulate token start_offsets and end_offsets
        my ( @starts, @ends );
        $self->_reset_pos();
        while (m/$separator_rx/g) {
            my $start = $self->_bytes_pos( \$_ );
            push @starts, $start;
            last unless m/$token_rx/g;
            my $end = $self->_bytes_pos( \$_ );
            
            # Skip tokens too big for kinosearch
            next if( ($end - $start) > 65535 );
            push @ends, $end;
        }
        $#starts = $#ends;  # correct for overshoot

        # add the new tokens to the batch
        $new_batch->add_many_tokens( $_, \@starts, \@ends ) if @starts;
    }

    return $new_batch;
}

sub _get_token_rx {
    my $self     = shift;
    my $words    = qr/\b(?:\w+(?:'\w+)?)\b/o;
    my $versions = qr/\b(?:(?:\d+\.){2,}\d+)\b/o;
    my $parts    = qr/\b(?:(?:\w+-)+\w+)\b/o;
    my $decimals = qr/(?:-?[\d\.]+)/o;
    my $dollars  = qr/(?:\p{CurrencySymbol}$decimals)/o;
    my $percents = qr/(?:$decimals\%)/o;
    return qr/(?:$versions|$parts|$dollars|$percents|$decimals\b|$words)/osm;
}

sub _get_token_seperator_rx {
    my ( $self, $token_rx ) = @_;
    $token_rx ||= $self->_get_token_rx || '\w+';
    return qr/.*?(?=$token_rx|\z)/osm;
}

# KinoSearch stores tokens by storing the original string once and then
# referencing tokens within that string through a list of start/end offset
# pairs.
#
# For example: Assume our string is "foo-bar", which contains two tokens "foo"
# and "bar".  Then KinoSearch stores "foo-bar" and a then two start/end offset
# pairs:  [0,2] (for "foo") and [4,6] (for "bar").
#
# While this approach is fine it causes a problem in that KinoSearch does not
# correctly understand UTF-8.  Those start/end offsets are treated as *byte*
# offsets in the original string, not character offsets.  This causes some
# problems in that multi-byte characters screw up tokenization.
#
# The workaround is to create a function, _bytes_pos, which acts like
# bytes::pos() would if it existed.  That is, it is a byte oriented version of
# the Perl builtin pos() function.   
#
# We also make use of an optimization that assumes _bytes_pos() is always
# called with pos() increasing monotonically.  This is a safe assumption
# because of how our algorithim in analyze() calls _bytes_pos().  The
# optimization lets us reuse previous calls to _bytes_pos() to avoid
# recomputing byte counts.  In practice this means a 4.3 MB chunk of text is
# indexed in 16 seconds instead of 20 minutes on standard 2006 Socialtext
# DevHardware.
#
# The optimization manifests itself through the use of $last_byte and
# $last_pos which remember the last byte returned and the character position
# that byte belongs to.  reset_pos() can be used to reset these private
# counters.
{
    my $last_byte = 0;
    my $last_pos  = 0;

    sub _reset_pos {
        ( $last_byte, $last_pos ) = ( 0, 0 );
    }

    sub _bytes_pos {
        my ( $self, $string_ref ) = @_;
        my $pos = pos $$string_ref;

        # Don't double count if we're given the same $pos twice.
        return $last_byte if $last_pos == $pos;

        # This function is specifically optimized for a monotonically
        # increasing $pos.  Die if we're giving a $pos less than $last_pos
        die "Error: bytes_pos $pos < $last_pos\n" if $pos < $last_pos;

        # Find the number of bytes in $$string_ref up to $pos.  The basic idea
        # here is to count the number of bytes in the substring between the
        # start of the string and pos().  The answer is the bytes equivalent
        # of pos().
        #
        # Our optimization make use of the fact that pos() increases
        # monotonically, and thus only grabs the substring between the
        # previous call, $last_pos, up to pos() which is $pos - $last_pos.
        # The bytes in that string are then added to a private counter, which
        # is reused on the next call.  Likewise $pos is saved in $last_pos for
        # use on the next call.
        my $substr = substr( $$string_ref, $last_pos, $pos - $last_pos );
        $last_byte += bytes::length($substr);
        $last_pos = $pos;

        return $last_byte;
    }
}

1;
