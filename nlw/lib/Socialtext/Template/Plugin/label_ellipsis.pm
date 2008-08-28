package Socialtext::Template::Plugin::label_ellipsis;
# @COPYRIGHT@

use strict;
use warnings;

use Template::Plugin::Filter;
use base qw( Template::Plugin::Filter );

sub init {
    my $self = shift;

    $self->{ _DYNAMIC } = 0;

    # first arg can specify filter name
    $self->install_filter($self->{ _ARGS }->[0] || 'label_ellipsis');

    return $self;
}

sub _label_ellipsis {
    my ($string, $length) = @_;
    my $new_string = '';

    return $string if (length($string) <= $length);

    my @parts = split / /, $string;

    if (scalar(@parts) == 1) {
        $new_string = substr $string, 0, $length;
    }
    else {
        foreach my $part (@parts) {
            last if ((length($new_string) + length($part)) > $length);
            $new_string .= $part . ' ';
        }
    }

    $new_string =~ s/\s+$//;
    $new_string .= '...';
    return $new_string;
}

sub filter {
    return _label_ellipsis( $_[1], $_[2] );
}

1;
