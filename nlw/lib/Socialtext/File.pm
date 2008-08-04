# @COPYRIGHT@
package Socialtext::File;
use strict;
use warnings;
use base 'Exporter';
our @EXPORT_OK = qw(set_contents get_contents ensure_directory);

=head1 NAME

Socialtext::File - Assorted file and I/O utility routines.

=cut

use Carp ();
use Fcntl qw(:flock);
use File::Path;
use File::Spec;
use File::Temp;
use File::Find;
use Encode::Guess;

# NOTE: Please don't add any Socialtext::* dependencies.  This module
# should be able to be used by any other socialtext code without
# worrying about what dependencies are getting pulled in.

=head1 SUBROUTINES

=head2 set_contents( $filename, $context [, $is_utf8 ] )

Creates file at I<$filename>, dumps I<$content> into the file, and
closes it.  If I<$is_utf8> is set, sets the C<:utf8> binmode on the file.

Returns I<$filename>.

=head2 set_contents_utf8( $filename, $content )

A simple UTF8 wrapper around L<set_contents()>.

=cut

sub set_contents {
    my $file = shift;
    my $content = shift;
    my $utf8  = shift;

    my $fh;
    open $fh, ">", $file or Carp::confess( "unable to open $file for writing: $!" );
    binmode($fh, ':utf8') if $utf8;
    print $fh $content;
    close $fh or die "Can't write $file: $!";
    return $file;
}

sub set_contents_utf8 {
    return set_contents(shift, shift, 1);
}

=head2 get_contents( $filename, [, $is_utf8 ] )

Slurps the file at I<$filename> and returns the content.  In list context,
returns a list of the lines in the file.  In scalar context, returns a
big string.

In either case, if I<$is_utf8> is set, sets the C<:utf8> binmode on
the file.

Returns I<$filename>.

=head2 get_contents_utf8( $filename )

A simple UTF8 wrapper around L<get_contents()>.

=cut

sub get_contents {
    my $file = shift;
    my $utf8  = shift;

    my $fh;
    open $fh, '<', $file or Carp::confess( "unable to open $file: $!" );
    binmode($fh, ':utf8') if $utf8;

    if (wantarray) {
        my @contents = <$fh>;
        close $fh;
        return @contents;
    }

    my $contents = do { local $/; <$fh> };
    close $fh;
    return $contents;
}

sub get_contents_based_on_encoding {
    my $class = shift;
    my $file = shift;
    my $encoding  = shift;

    my $fh;
    open $fh, '<', $file or Carp::confess( "unable to open $file: $!" );
    binmode($fh, ':encoding('. $encoding . ')');

    if (wantarray) {
        my @contents = <$fh>;
        close $fh;
        return @contents;
    }

    my $contents = '';
    eval { local $/; $contents = <$fh> };
    warn $@ if $@;
    close $fh;
    return $contents;
}

sub get_contents_or_empty {
    my $contents;
    eval { $contents = get_contents(@_) };
    $contents = '' if ($@);
    return $contents;
}

sub get_contents_utf8 {
    return get_contents(shift, 1);
}

my $locale_encoding_names = {
    'ja' => 'euc-jp shiftjis cp932 iso-2022-jp utf8',
    'en' => 'utf8',
};

sub get_guess_encoding {
    my $self = shift;
    my $locale = shift;
    my $file_full_path = shift;

    my $data;

    unless ( -e $file_full_path ) {
        return 'utf8';
    }

    open (FH, $file_full_path);
    my $len = -s $file_full_path;
    read FH, $data, $len;
    close FH;

    my $encoding_names = $locale_encoding_names->{$locale};
    if ( ! defined $encoding_names) {
        return 'utf8';
    }
    my @match_list = split(/\s/, $encoding_names);
    my $enc = Encode::Guess::guess_encoding($data, @match_list);
    if ( ref($enc) ) {
        return $enc->name;
    } else {
        foreach (@match_list) {
            if ( $enc =~ /$_/ ) {
                return $_;
            }
        }
        return 'utf8';
    }
}

sub _guess_string_encoding {
    my $class = shift;
    my $locale = shift;
    my $data = shift;
    my $encoding_names = $locale_encoding_names->{$locale};
    if ( ! defined $encoding_names) {
        return 'utf8';
    }
    my @match_list = split(/\s/, $encoding_names);
    my $enc = Encode::Guess::guess_encoding($data, @match_list);
    if ( ref($enc) ) {
        return $enc->name;
    } else {
        foreach (@match_list) {
            if ( $enc =~ /$_/ ) {
                return $_;
            }
        }
        return 'utf8';
    }
}

sub ensure_directory {
    my $directory = shift;
    my $mode = shift || 0755;
    return if -e $directory;
    eval { File::Path::mkpath $directory, 0, $mode };
    Carp::confess( "unable to create directory path $directory: $@" ) if $@;
}

=head2 ensure_empty_file($path, $tmp_path)

Attempts to ensure that $path exists on disk.  The mechanism is to first try
to create $tmp_path (unlinking any old, existing $tmp_path first), then link
it to $path.  If the link is either created or fails due to a link already
being present, $tmp_path is unlinked and the subroutine returns successfully.
If another process is racing to create the file at the same time, only one
will win, but both processes can then see and use the same file.  This is
particularly useful for ensuring two processes are using the same lock file.

If $tmp_path is not given, then ".$$" is appended to $path instead.

If any unexpected errors occur, this subroutine C<die()>s.

=cut

sub ensure_empty_file {
    my $path = shift;
    my $tmp_path = shift || "$path.$$";

    unless (unlink $tmp_path) {
        # The only acceptable error here is that the file didn't exist to
        # begin with.
        Carp::confess( "unlink '$tmp_path': $!" ) unless $!{ENOENT};
    }

    # XXX fix the perms here
    open my $l, '>', $tmp_path or Carp::confess( "create '$tmp_path': $!" );
    close $l or Carp::confess( "create '$tmp_path': $!" );
    unless (link $tmp_path, $path) {
        # The only acceptable error here is that the target ($path) already
        # existed.
        Carp::confess( "link '$tmp_path' -> '$path': $!" ) unless $!{EEXIST};
    }

    # REVIEW: This isn't really fatal, but I don't like to warn() in library
    # code.  How should we warn the caller?
    Carp::confess( "unlink '$tmp_path': $!" ) unless unlink $tmp_path;
}

sub directory_is_empty {
    my $directory = shift;
    opendir my $dh, $directory or Carp::confess( "unable to open directory: $!\n" );
    for my $e ( readdir $dh ) {
        return 0 unless $e =~ /^\.\.?$/;
    }
    return 1;
}

sub all_directory_files {
    my $directory = shift;
    opendir my $dh, $directory or Carp::confess( "unable to open directory: $!\n" );
    return grep { !/^(?:\.|\.\.)$/ && -f catfile( $directory, $_ ) }
        readdir $dh;
}

sub all_directory_directories {
    my $directory = shift;
    opendir my $dh, $directory or Carp::confess( "unable to open directory: $!\n" );
    return grep { !/^(?:\.|\.\.)$/ && -d catfile( $directory, $_ ) }
        readdir $dh;
}

sub catdir {
    if ( grep { ! defined } @_ ) {
        Carp::cluck('Undefined value passed to Socialtext::File::catdir');
    }
    return join('/', @_);
}

sub catfile {
    if ( grep { ! defined } @_ ) {
        Carp::cluck('Undefined value passed to Socialtext::File::catfile');
    }
    return join('/', @_);
}

sub tmpdir {
    return File::Spec->tmpdir;
}

sub temp_template_for {
    my $usage_string = shift;
    my $temptemplate = "/tmp/nlw-$usage_string-$$-$<-XXXXXXXXXX";
}

sub update_mtime {
    my $file = shift;
    my $time = shift || time;

    # REVIEW - there's a race condition here, but does it actually
    # matter? I don't think it does for files that are only being used
    # as timestamps, without any actual content (as in
    # Socialtext::EmailNotifyPlugin)
    unless ( -f $file ) {
        open my $fh, '>', $file
            or Carp::confess( "Cannot write to $file: $!" );
        close $fh;
    }

    utime $time, $time, $file
        or Carp::confess( "Cannot call utime on $file: $!" );
}

=head2 write_lock($file)

Given a file, attempts to lock this file for writing. Returns a
filehandle opened for writing to the file.

=cut

sub write_lock {
    my $file = shift;

    open my $fh, '>', $file
        or Carp::confess( "Cannot write to $file: $!" );
    flock $fh, LOCK_EX
        or Carp::confess( "Cannot lock $file for writing: $!" );

    return $fh;
}

=head2 files_under( @dirs )

Given a list of directories, returns a list of all the files in those
directories and below.

=cut

sub files_under {
    my @starting = @_;

    my @files;

    my $sub = sub { push @files, $File::Find::name if -f };
    find( { untaint => 1, wanted => $sub }, @starting );

    return @files;
}

=head2 files_and_dirs_under( @dirs )

Given a list of directories, returns a list of all the files and
directories in those directories and below.

=cut

sub files_and_dirs_under {
    my @starting = @_;

    my @files;

    my $sub = sub { push @files, $File::Find::name if -f || -d };
    find( { untaint => 1, wanted => $sub }, @starting );

    return @files;
}

=head2 clean_directory($path)

Remove all files and subdirectories from the specified directory.

If any unexpected errors occur, this subroutine C<die()>s.

=cut

sub clean_directory {
    my $directory = shift;

    rmtree($directory);
    ensure_directory($directory);
}

=head2 remove_directory($path)

Delete a directory.

If any unexpected errors occur, this subroutine C<die()>s.

=cut

sub remove_directory {
    my $directory = shift;

    eval { rmtree($directory) };
    Carp::confess( "unable to remove directory path $directory: $@" ) if $@;
}

=head2 safe_symlink($filename, $symlink)

Safely create a symlink 'symlink' that refers to 'filename'.

=cut

sub safe_symlink {
    my $filename = shift;
    my $symlink = shift;
    my $tmp_symlink = "$symlink.$$";
    symlink $filename, $tmp_symlink
        or die "Can't create symlink '$tmp_symlink': $!";
    rename $tmp_symlink => $symlink
        or die "Can't rename '$tmp_symlink' to '$symlink': $!";
}

=head1 SEE ALSO

L<Socialtext::Paths>

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
