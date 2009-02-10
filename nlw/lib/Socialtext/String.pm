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
    return HTML::Entities::encode_entities(shift, q/<>&"'/);
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

=head2 uri_unescape( $uri )

Returns an unescaped version of I<$uri>

=cut

sub uri_unescape {
    return URI::Escape::uri_unescape(shift)
}

=head2 double_space_harden( $str )

Adds hard spaces in I<$str> where there's two space characters.

=cut

sub double_space_harden {
    my $str = shift;
    $str =~ s/  / \x{00a0}/g;
    return $str;
}

=head2 word_truncate ($str, $length)

Return a truncated I<$str> to a maximum of I<$length> characters and append
I<$ellipsis> if text was truncated.  C<word_truncate> breaks on whitespace, so
that words are not chopped in half.

=cut

sub word_truncate {
    my ($string, $length, $ellipsis) = @_;
    $ellipsis ||= '...';
    return $ellipsis if !$length;

    my $new_string = '';

    return $string if (length($string) <= $length);
    return $ellipsis if (0 == $length);

    my @parts = split / /, $string;

    if (scalar(@parts) == 1) {
        $new_string = substr $string, 0, $length;
    }
    else {
        foreach my $part (@parts) {
            last if ((length($new_string) + length($part)) > $length);
            $new_string .= $part . ' ';
        }
        $new_string = substr($parts[0], 0, $length) if (length($new_string) == 0);

    }

    $new_string =~ s/\s+$//;
    $new_string .= $ellipsis;
    return $new_string;
}

1;
