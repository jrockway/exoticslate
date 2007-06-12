# @COPYRIGHT@
package Socialtext::Encode;
use strict;
use warnings;

use Encode;
use Encode::Guess qw(latin1);
use Socialtext::Validate qw[validate SCALAR_TYPE];

sub is_valid_utf8 {
    my $copy = shift;
    Encode::_utf8_on($copy); # XXX darnit!  is there a less-ugly way to do this?
    return Encode::is_utf8($copy, 1);
}

sub noisy_decode {
    my %args = validate @_, {
        input => SCALAR_TYPE,
        blame => SCALAR_TYPE,
    };
    if ( Socialtext::Encode::is_valid_utf8( $args{input} ) ) {
        return Encode::decode( 'utf8', $args{input} );
    } else {
        warn "$args{blame}: doesn't seem to be valid utf-8";
        my $guess = Encode::Guess->guess( $args{input} );
        warn "$args{blame}: Treating as " . $guess->name;
        return $guess->decode( $args{input} );
    }
}

sub ensure_is_utf8 {
    my $bytes = shift;
    return
        Encode::is_utf8($bytes)
            ? $bytes
            : Encode::decode_utf8($bytes);
}

1;
