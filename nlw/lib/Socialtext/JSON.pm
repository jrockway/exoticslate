package Socialtext::JSON;

# Required inclusions.
use strict;
use warnings;
use JSON::XS qw();

# Export our methods.
use base qw(Exporter);
our @EXPORT_OK = qw(
    encode_json
    decode_json
    );
our @EXPORT = @EXPORT_OK;

sub encode_json {
    # defer to JSON::XS
    

    unless (ref $_[0]) {
        # manually encode a string because heaven forbid anyone would be
        # stupid enough to *want* to do that. 
        my $val = shift;
        $val =~ s|"|\\"|g;
        return qq("$val");
    }
    return JSON::XS::encode_json($_[0]);
}

sub decode_json {
    # defer to JSON::XS
    return JSON::XS::decode_json($_[0]);
}

1;

=head1 NAME

Socialtext::JSON - JSON en/decoding routines

=head1 SYNOPSIS

  use Socialtext::JSON;

  $utf8_encoded_json_text = encode_json( $perl_hash_or_arrayref );
  $perl_hash_or_arrayref  = decode_json( $utf8_encoded_json_text );

=head1 DESCRIPTION

C<Socialtext::JSON> provides a single point of entry for JSON en/decoding
routines.  JSON support in Perl has been notorious for having differing
implementations, and as a programmer there's always some sense of having to
use "the flavour of the month".

Thus, C<Socialtext::JSON>.  Use it, and if/when we ever decide we need to
change the way that we're handling JSON data, we've only got to do it in
B<one> place.

=head1 METHODS

The following methods are exported automatically:

=over

=item B<encode_json($perl_hash_or_arrayref)>

Converts the given Perl data structure to a UTF-8 encoded, binary string (that
is, the string contains octets only).  Croaks on error.

=item B<decode_json($utf8_encoded_json_text)>

Opposite of C<encode_json()>; expects a UTF-8 encoded, binary string and ties
to parse that as UTF-8 encoded JSON text returning the resulting reference.
Croaks on error.

=back

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
