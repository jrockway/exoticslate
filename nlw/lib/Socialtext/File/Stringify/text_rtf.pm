# @COPYRIGHT@
package Socialtext::File::Stringify::text_rtf;
use strict;
use warnings;

use Socialtext::File::Stringify::Default;
use Socialtext::System;

sub to_string {
    my ( $class, $file ) = @_;
    my $text = Socialtext::System::backtick(
        "unrtf", "--nopict", "--text",
        $file
    );

    if ( $? or $@ ) {
        $text = Socialtext::File::Stringify::Default->to_string($file);
    }
    elsif ( defined $text ) {
        $text =~ s/^.*?-----------------\n//s; # Remove annoying unrtf header.
        $text = Socialtext::File::Stringify::Default->to_string($file) if $?;
    }
    return $text;
}

1;
