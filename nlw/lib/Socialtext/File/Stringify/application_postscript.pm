# @COPYRIGHT@
package Socialtext::File::Stringify::application_postscript;
use strict;
use warnings;

use Socialtext::File::Stringify::Default;
use Socialtext::System;

sub to_string {
    my ( $class, $file ) = @_;
    my $text = Socialtext::System::backtick( "ps2ascii", $file );
    $text = Socialtext::File::Stringify::Default->to_string($file) if $? or $@;
    return $text;
}

1;
