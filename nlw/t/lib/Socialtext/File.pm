package Socialtext::File;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Exporter';

our @EXPORT_OK = qw/get_contents set_contents/;

our %CONTENT;

sub get_contents {
    my $filename = shift;
    if (my $content = $CONTENT{$filename}) {
        return $content;
    }
    warn "Returning mock content for path: '$filename'";
    return 'empty mock content';
}

sub set_contents {
    my $filename = shift;
    my $content = shift;
    $CONTENT{$filename} = $content;
}

sub get_contents_utf8 { get_contents(@_) }
sub set_contents_utf8 { set_contents(@_) }

1;
