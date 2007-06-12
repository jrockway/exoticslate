# @COPYRIGHT@
package Socialtext::String;
use strict;
use warnings;
use HTML::Entities ();
use URI::Escape ();

=head1 Socialtext::String

A collection of random string functions.

=head2 html_escape( $str )

Returns an HTML-escaped version of the I<$str>, replacing '<', '>',
'&' and '"' with their HTML entities.

=cut

sub html_escape {
    return HTML::Entities::encode_entities(shift, '<>&"');
}

=head2 html_unescape( $str )

Returns unescaped version of the I<$str>.

=cut

sub html_unescape { 
    return HTML::Entities::decode_entities(shift);
}

=head2 trim( $str )

Trims leading and trailing whitespace.  Does not remove taintedness from
the string.

=cut

sub trim {
    my $str = shift;
    $str =~ s/^\s+//;
    $str =~ s/\s+$//;
    return $str;
}

=head2 uri_escape( $str )

Returns an escaped version of I<$str>

=cut

sub uri_escape {
    return URI::Escape::uri_escape_utf8(shift);
}

=head2 double_space_harden( $str )

Adds hard spaces in I<$str> where there's two space characters.

=cut

sub double_space_harden {
    my $str = shift;
    $str =~ s/  / \x{00a0}/g;
    return $str;
}

1;
