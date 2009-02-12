# @COPYRIGHT@
package Socialtext::Image;
use strict;
use warnings;

use Socialtext::System qw(shell_run);
use Carp ();
use Readonly;
use IO::Handle;
use IO::File;
use Socialtext::Validate qw( validate SCALAR_TYPE OPTIONAL_INT_TYPE HANDLE_TYPE );

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

        my $file = $p{filename} || die "Filename is required";

        ($p{img_width}, $p{img_height}) = split ' ', `identify -format '\%w \%h' $file`;
        my ($new_width, $new_height) = get_proportions(%p);

        if ($new_width and $new_height) {
            local $Socialtext::System::SILENT_RUN = 1;
            shell_run("convert -quiet $file -scale ${new_width}x${new_height} $file");
        }
    }
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

    my ($w, $h) = split ' ', `identify -format '\%w \%h' $img`;

    local $Socialtext::System::SILENT_RUN = 1;

    if ($h > $max_h && $w > $max_w) {
        my ($new_w, $new_h) = Socialtext::Image::get_proportions(
            new_width  => $w,
            new_height => $h,
            max_width  => $max_w,
            max_height => $max_h
        );
        my $border_w = int(.5 + ($max_w - $new_w) / 2);
        my $border_h = int(.5 + ($max_h - $new_h) / 2);

        shell_run(
            "convert -quiet $img -scale ${new_w}x${new_h}! "
           ."-bordercolor #FFFFFF "
           ."-border ${border_w}x${border_h} $img"
        );
    }
    elsif ($h > $max_h) {
        my $border_w = int($max_w - $w) / 2;
        my $border_h = 0;
        shell_run(
            "convert -quiet $img -crop ${max_w}x${max_h}! "
           ."-bordercolor #FFFFFF "
           ."-border ${border_w}x${border_h} $img"
        );
    }
    elsif ($w > $max_w) {
        my $border_w = 0;
        my $border_h = ($max_h - $h) / 2;
        shell_run(
            "convert -quiet $img -crop ${max_w}x${max_h}! "
           ."-bordercolor #FFFFFF "
           ."-border ${border_w}x${border_h} $img"
        );
    }
    else {
        # image is smaller than our maximum bounds, so lets create a border
        # around it to pad the edges. this will have the nice side effect of
        # centering the image
        my ($bw, $bh) = (($max_w - $w) / 2, ($max_h - $h) / 2);
        shell_run(
            "convert -quiet -bordercolor #FFFFFF "
           ."-border ${bw}x${bh} $img"
        );
    }
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

1;
