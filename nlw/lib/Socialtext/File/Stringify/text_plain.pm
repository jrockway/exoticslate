# @COPYRIGHT@
package Socialtext::File::Stringify::text_plain;
use strict;
use warnings;

use Socialtext::File;

sub to_string {
    my ( $class, $filename ) = @_;
    return scalar Socialtext::File::get_contents_utf8($filename);
}

1;
