# @COPYRIGHT@
package Socialtext::Image;
use strict;
use warnings;

use Carp ();
use Readonly;
use IO::Handle;
use IO::File;
use Socialtext::Validate qw( validate SCALAR_TYPE OPTIONAL_INT_TYPE HANDLE_TYPE );

use constant HAS_IM => eval { require Image::Magick; 1 };


{
    Readonly my $spec => {
        max_width  => OPTIONAL_INT_TYPE,
        max_height => OPTIONAL_INT_TYPE,
        new_width  => OPTIONAL_INT_TYPE,
        new_height => OPTIONAL_INT_TYPE,
        filename   => SCALAR_TYPE,
    };


    sub resize {
        my %p = validate( @_, $spec );

        my $img = get_image($p{filename});

        $p{img_height} = $img->Get('height');
        $p{img_width} = $img->Get('width');
        my ($new_width, $new_height) = get_proportions(%p);

        if ($new_width and $new_height) {
            _check_magick_error( $img->Scale(
                height => $new_height,
                width  => $new_width,
            ) );
        }

        _check_magick_error( $img->Write( filename => $p{filename} ) );
    }
}

sub get_image {
    my ($filename, $filehandle) = @_;
    unless ( HAS_IM ) {
        warn "Image::Magick is not installed, so we cannot resize images."
             . " Copying image to $filename.\n";
        return;
    }
    my $img = Image::Magick->new;
    my $fh = IO::File->new($filename, "r");
    _check_magick_error( $img->Read( file => $fh ) );
    return $img;
}

sub shrink {
    my ($w,$h,$max_w,$max_h) = @_;
    my $over_w = $max_w ? $w / $max_w : 0;
    my $over_h = $max_h ? $h / $max_h : 0;
    if ($over_w > 1 and $over_w > $over_h) {
        $w /= $over_w;
        $h /= $over_w;
    }
    elsif ($over_h > 1 and $over_h >= $over_w) {
        $w /= $over_h;
        $h /= $over_h;
    }
    return ($w,$h);
}

sub get_proportions {
    my %p = @_;

    my ($width,$height) = (0,0);
    my $ratio = 1;

    if ($p{new_width} and $p{new_height}) {
        ($width,$height) = shrink($p{new_width}, $p{new_height},
                                  $p{max_width}, $p{max_height});
    }
    elsif ($p{new_width}) {
        $ratio = $p{img_width} / $p{img_height};
        $width = $p{new_width};
        $height = $width / $ratio;
        ($width,$height) = shrink($width,$height,$p{max_width},$p{max_height});
    }
    elsif ($p{new_height}) {
        $ratio = $p{img_width} / $p{img_height};
        $height = $p{new_height};
        $width = $height * $ratio;
        ($width,$height) = shrink($width,$height,$p{max_width},$p{max_height});
    }
    else {
        ($width,$height) = shrink($p{img_width}, $p{img_height},
                                  $p{max_width}, $p{max_height});
    }

    return ($width,$height);
}

# Image::Magick returns undef on success, a string on error.
sub _check_magick_error {
    my $err = shift;

    return unless defined $err and length $err;

    Carp::croak($err);
}


1;

