# @COPYRIGHT@
package Socialtext::File::Stringify::text_html;
use strict;
use warnings;

use Socialtext::File::Stringify::Default;
use Socialtext::System;

sub to_string {
    my ( $class, $file ) = @_;
    my $text = Socialtext::System::backtick( "lynx", "-dump", $file );
    $text = Socialtext::File::Stringify::Default->to_string($file) if $? or $@;
    return $text;
}

1;
