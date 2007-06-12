# @COPYRIGHT@
package Socialtext::File::Stringify::Default;
use strict;
use warnings;

use Socialtext::System;
use MIME::Types;

sub to_string {
    my ( $class, $filename ) = @_;
    my $mime = MIME::Types->new->mimeTypeOf($filename) || "";

    # These produce huge output that is 99% not useful, so just do nothing.
    return "" if $mime =~ m{^(image|video|audio)/.*};  

    return Socialtext::System::backtick( 'strings', $filename );
}

1;
