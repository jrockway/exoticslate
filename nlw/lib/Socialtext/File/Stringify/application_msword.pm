# @COPYRIGHT@
package Socialtext::File::Stringify::application_msword;
use strict;
use warnings;

use File::Temp;
use Socialtext::File;
use Socialtext::File::Stringify::Default;

sub to_string {
    my ( $class, $filename ) = @_;

    my ( undef, $temp_filename ) = File::Temp::tempfile(
        Socialtext::File::temp_template_for('indexing_word_attachment'),
        CLEANUP => 1,
    );

    # If 'wvText' fails, fall back on the "any' mode.
    my $text =
        ( system 'wvText', $filename, $temp_filename ) == 0
        ? Socialtext::File::get_contents_utf8($temp_filename)
        : Socialtext::File::Stringify::Default->to_string($filename);

    unlink $temp_filename;
    return $text;
}

1;
