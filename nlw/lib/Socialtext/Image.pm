# @COPYRIGHT@
package Socialtext::Image;
use strict;
use warnings;

use Carp ();
use File::Copy ();
use Readonly;
use IO::Handle;
use Socialtext::Validate qw( validate SCALAR_TYPE POSITIVE_INT_TYPE HANDLE_TYPE );

use constant HAS_IM => eval { require Image::Magick; 1 };


{
    Readonly my $spec => {
        filehandle => HANDLE_TYPE,
        max_width  => POSITIVE_INT_TYPE,
        max_height => POSITIVE_INT_TYPE,
        file       => SCALAR_TYPE,
    };


    sub resize {
        my %p = validate( @_, $spec );

        unless ( HAS_IM ) {
            warn "Image::Magick is not installed, so we cannot resize images."
                 . " Copying image to $p{file}.\n";
            File::Copy::copy( $p{filehandle}, $p{file} );
            return;
        }

        my $img = Image::Magick->new;
        ## 
        # as reported in RT: 26314, The lightweight flyhandle returned by CGI::upload
        # doesn't work well when passed into Image::Magick.  So, we're going to create
        # a new file handle that Image::Magick will like using the fileno of the
        # lightweight one that came from CGI::upload.
        # We _could_ be a bit more cautious about this and only do it if the type
        # of $p{filehandle} is one of those passed to us from CGI::upload.  But
        # I don't think that's necessary.
        my $io = new IO::Handle;
        my $real_live_handle = $io->fdopen( fileno( $p{filehandle} ), "r" );

        _check_magick_error( $img->Read( file => $real_live_handle ) );
        ## 
        my $height = $img->Get('height');
        my $width  = $img->Get('width');

        if ( $height > $p{max_height}
             or $width  > $p{max_width} ) {

            my $height_r = $p{max_height} / $height;
            my $width_r  = $p{max_width} / $width;

            my $ratio = $height_r < $width_r ? $height_r : $width_r;

            _check_magick_error( $img->Scale(
                height => $height * $ratio,
                width  => $width * $ratio,
            ) );
        }

        _check_magick_error( $img->Write( filename => $p{file} ) );
    }
}

# Image::Magick returns undef on success, a string on error.
sub _check_magick_error {
    my $err = shift;

    return unless defined $err and length $err;

    Carp::croak($err);
}


1;

