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
        filename   => SCALAR_TYPE( default => '' ),
        blob       => SCALAR_TYPE( default => '' ),
    };


    sub resize {
        my %p = validate( @_, $spec );

        die "Filename or blob is required"
            unless $p{filename} || $p{blob};

        my $img = defined $p{filename} 
            ? get_image_from_file($p{filename})
            : get_image_from_blob($p{blob});

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

sub get_image_from_file {
    my $filename = shift;
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

sub get_image_from_blob {
    my $blob = shift;

    my $img = Image::Magick->new;
    _check_magick_error( $img->BlobToImage($blob));
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

sub MAX_LARGE_IMAGE_WIDTH  { 64 }
sub MAX_LARGE_IMAGE_HEIGHT { 64 }
sub MAX_SMALL_IMAGE_WIDTH  { 27 }
sub MAX_SMALL_IMAGE_HEIGHT { 27 }
sub BORDER_COLOUR { '#FFFFFF' }

# scale and crop a profile image. you can find the "spec" for this function
# at:
#     https://www2.socialtext.net/dev-tasks/index.cgi?story_user_can_upload_photo_to_their_people_profile
sub process_profile_image {
    my %p = @_;

    die "'image' and 'size' parameters are required"
        unless ($p{image} && $p{size});

    my $img = $p{image};
    my $size = $p{size};
    my ($max_w, $max_h);

    if ($size eq 'large') {
        $max_w = MAX_LARGE_IMAGE_WIDTH;
        $max_h = MAX_LARGE_IMAGE_HEIGHT;
    } elsif ($size eq 'small') {
        $max_w = MAX_SMALL_IMAGE_WIDTH;
        $max_h = MAX_SMALL_IMAGE_HEIGHT;
    } else {
        die "Invalid size '$size'";
    }

    my $h = $img->Get('height');
    my $w = $img->Get('width');

    if ($h > $max_h && $w > $max_w) {
        my ($new_w, $new_h) = Socialtext::Image::get_proportions(
            new_width  => $w,
            new_height => $h,
            max_width  => $max_w,
            max_height => $max_h
        );
        Socialtext::Image::_check_magick_error(
            $img->Scale(
                width  => $new_w,
                height => $new_h
            )
        );
        Socialtext::Image::_check_magick_error(
            $img->Border(
                width  => int(.5 + ($max_w - $new_w) / 2),
                height => int(.5 + ($max_h - $new_h) / 2),
                color  => '#FFFFFF'
            )
        );
    }
    elsif ($h > $max_h) {
        my %crop_geometry = crop_geometry(
            width     => $w,     height     => $h,
            max_width => $max_w, max_height => $max_h
        );

        # crop and pad edges
        Socialtext::Image::_check_magick_error($img->Crop(%crop_geometry));
        Socialtext::Image::_check_magick_error(
            $img->Border(
                width  => ($max_w - $w) / 2,
                height => 0, color => '#FFFFFF'
            )
        );
    }
    elsif ($w > $max_w) {
        my %crop_geometry = crop_geometry(
            width     => $w,     height      => $h,
            max_width => $max_w, max_height => $max_h
        );

        # crop and pad edges
        Socialtext::Image::_check_magick_error($img->Crop(%crop_geometry));
        Socialtext::Image::_check_magick_error(
            $img->Border(
                height => ($max_h - $h) / 2,
                width  => 0, color => BORDER_COLOUR
            )
        );
    }
    else {
        # image is smaller than our maximum bounds, so lets create a border
        # around it to pad the edges. this will have the nice side effect of
        # centering the image
        
        my ($bw, $bh) = (($max_w - $w) / 2, ($max_h - $h) / 2);
        Socialtext::Image::_check_magick_error(
            $img->Border(width => $bw, height => $bh, color => BORDER_COLOUR)
        );
    }

    return $img;
}

sub crop_geometry {
    my %p = @_;
    my ($width, $height) = ($p{width}, $p{height});
    my ($max_width, $max_height) = ($p{max_width}, $p{max_height});

    my %geometry = (
        width => $width, height => $height,
        x => 0, y => 0
    );

    if ($width > $max_width && $height <= $max_height) {
        $geometry{width}  = $max_width;
        $geometry{height} = $height;
        $geometry{x}      = ($width - $max_width) / 2;
        $geometry{y}      = 0;
    }
    elsif ($height > $max_height && $width <= $max_width) {
        $geometry{width}  = $width;
        $geometry{height} = $max_height;
        $geometry{x}      = 0;
        $geometry{y}      = ($height - $max_height) / 2;
    }

    return %geometry;
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
