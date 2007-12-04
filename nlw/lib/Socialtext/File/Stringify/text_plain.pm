# @COPYRIGHT@
package Socialtext::File::Stringify::text_plain;
use strict;
use warnings;

use Socialtext::File;
use Socialtext::l10n qw(system_locale);

sub to_string {
    my ( $class, $filename ) = @_;
    my $encoding = Socialtext::File->get_guess_encoding(system_locale(), $filename);
    my $text = scalar Socialtext::File->get_contents_based_on_encoding($filename, $encoding);
    return $text;
}

1;
