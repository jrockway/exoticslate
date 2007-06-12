# @COPYRIGHT@
package Socialtext::File::Stringify::audio_mpeg;
use strict;
use warnings;

use Socialtext::File::Stringify::Default;

sub to_string {
    my ( $class, $file ) = @_;
    my $text = "";
    eval {
        require MP3::Tag;
        my $mp3  = MP3::Tag->new($file);
        my $info = $mp3->autoinfo();
        die unless defined $info;
        for my $tag ( reverse sort keys %$info ) {
            $text .= uc($tag) . ": $info->{$tag}\n";
        }
    };
    $text = Socialtext::File::Stringify::Default->to_string($file) if $@;
    return $text;
}

1;
