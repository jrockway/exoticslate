# @COPYRIGHT@
package Socialtext::File::Stringify::application_vnd_ms_excel;
use strict;
use warnings;

use Socialtext::File::Stringify::Default;
use Socialtext::System;

sub to_string {
    my ( $class, $file ) = @_;
    my $text = Socialtext::System::backtick( "xls2csv", $file );
    if ( $? or $@ ) {
        $text = Socialtext::File::Stringify::Default->to_string($file);
    }
    elsif ( defined $text ) {
        $text =~ s/^"|"$//mg;
        $text =~ s/"+/"/g;
    }
    return $text;
}

1;
