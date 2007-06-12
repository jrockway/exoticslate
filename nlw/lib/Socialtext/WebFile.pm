# @COPYRIGHT@
package Socialtext::WebFile;
use strict;
use warnings;

use Socialtext::AppConfig;
use Socialtext::Helpers;
use Socialtext::UniqueArray;

sub new {
    my $class = shift;
    my %p     = @_;

    my $hub = $p{hub};

    my $self = bless {
        custom_files => [],
        uris         => Socialtext::UniqueArray->new,
        files        => Socialtext::UniqueArray->new,
    }, $class;

    $self->add_location( $class->RootDir(), $class->RootURI() );

    $self->_init($hub);

    $self->add_location( $class->RootDir() . '/local',
        $class->RootURI() . '/local' );

    # called after _init() to allow subclass to add additional paths
    $self->add_file($_) for $self->StandardFiles();

    return $self;
}

sub _init { }

sub add_path {
    my $self = shift;
    my $path = shift;

    my $legacy_path = $self->LegacyPath();

    # XXX - cleaning up old relative paths expecting a symlink
    $path =~ s{^\Q$legacy_path\E}{}g; # XXX can we get rid of this yet?

    my $fs_path = $self->RootDir() . '/' . $path;
    my $uri_prefix = $self->RootURI() . '/' . $path;
    $self->add_location( $fs_path, $uri_prefix );
}

sub add_location {
    my $self       = shift;
    my $fs_path    = shift;
    my $uri_prefix = shift;

    unshift @{ $self->{locations} },
      Socialtext::URI::ToDisk->new( $fs_path, $uri_prefix );
}

sub add_file {
    my $self = shift;
    my $file = shift;
    return unless defined $file && length $file;

    for my $l ( @{ $self->{locations} } ) {
        my $new_l = $l->catfile($file);
        if ( -f $new_l->path ) {
            $self->{uris}->push( $new_l->uri );
            $self->{files}->push( $new_l->path );
            last;
        }
    }
}

sub uris {
    my $self = shift;

    # Always want to make sure these are loaded last, since they may
    # override any earlier file
    $self->_add_custom();

    return $self->{uris}->values;
}

sub files {
    my $self = shift;

    # Always want to make sure these are loaded last, since they may
    # override any earlier file
    $self->_add_custom();

    return $self->{files}->values;
}

sub _add_custom {
    my $self = shift;

    $self->add_file($_) for @{ $self->{custom_files} };
}

# Following is an inlined, hacked version of Socialtext::URI::ToDisk.  It's only
# used here in Socialtext::WebFile.
#
# We hacked it to allow the URI portion to be a path, not a full URI
# (with scheme, etc)


package Socialtext::URI::ToDisk;

=pod

=head1 NAME

Socialtext::URI::ToDisk - Working with disk to URI file mappings

=head1 SYNOPSIS

  # We have a directory on disk that is accessible via a web server
  my $authors = Socialtext::URI::ToDisk->new( '/var/www/AUTHORS', '/uri/to/AUTHORS' );

  # We know where a particular generated file needs to go
  my $about = $authors->catfile( 'A', 'AD', 'ADAMK', 'about.html' );

  # Save the file to disk
  my $file = $about->path;
  open( FILE, ">$file" ) or die "open: $!";
  print FILE, $content;
  close FILE;

  # Show the user where to see the file
  my $uri = $about->uri;
  print "Author information is at $uri\n";

=head1 DESCRIPTION

In several process relating to working with the web, we may need to keep
track of an area of disk that maps to a particular URL. From this location,
we should be able to derived both a filesystem path and URL for any given
directory or file under this location that we might need to work with.

=head2 Implementation

Internally each C<Socialtext::URI::ToDisk> object contains both a filesystem path,
which is altered using L<File::Spec>, and a URI path altered using
L<File::Spec::Unix>.

=head2 Method Calling Conventions

The main functional methods, such as C<catdir> and C<catfile>, do B<not>
modify the original object, instead returning a new object containing the
new location.

This means that it should be used in a somewhat similar way to L<File::Spec>.

  # The File::Spec way
  my $path = '/some/path';
  $path = File::Spec->catfile( $path, 'some', 'file.txt' );
  
  # The Socialtext::URI::ToDisk way
  my $location = Socialtext::URI::ToDisk->new( '/some/path', '/blah' );
  $location = $location->catfile( 'some', 'file.txt' );

OK, well it's not exactly THAT close, but you get the idea. It also allows you
to do method chaining, which is basically

  Socialtext::URI::ToDisk->new( '/foo', '/' )->catfile( 'bar.txt' )->uri

Which may seem a little trivial now, but I expect it to get more useful later.
It also means you can do things like this.

  my $base = Socialtext::URI::ToDisk->new( '/my/cache', '/' );
  foreach my $path ( @some_files ) {
  	my $file = $base->catfile( $path );
  	print $file->path . ': ' . $file->uri . "\n";
  }

In the above example, you don't have to be continuously cloning the location,
because all that stuff happens internally as needed.

=head1 METHODS

=cut

use strict;
use File::Spec       ();
use File::Spec::Unix ();

# Overload stringification to the string form of the URL.
use overload 'bool' => sub () { 1 },
             '""'   => 'uri',
             'eq'   => '__eq';

use vars qw{$VERSION};
BEGIN {
	$VERSION = '1.08';
}





#####################################################################
# Constructors

=pod

=head2 new $path, $http_url_path

The C<new> constructor takes as argument a filesystem path and a http(s) 
URL. Both are required, and the method will return C<undef> is either is 
illegal. The URL is not required to have protocol, host or port sections,
and as such allows for host-relative URL to be used.

Returns a new C<Socialtext::URI::ToDisk> object on success, or C<undef> on failure.

=cut

sub new {
	my $class = shift;

	# Get the base file system path
	my $path = File::Spec->canonpath(shift) or return undef;

	# Get the base URI. We only accept HTTP(s) URLs
	return undef unless defined $_[0] and ! ref $_[0];
        my $uri = shift || '/';

	# Create the object
	bless { path => $path, uri => $uri }, $class;
}

=pod

=head2 param $various

C<param> is provided as a mechanism for higher order modules to flexibly
accept Socialtext::URI::ToDisk's as parameters. In this case, it accepts either
an existing Socialtext::URI::ToDisk object, two arguments ($path, $http_url), or
a reference to an array containing the same two arguments.

Returns a Socialtext::URI::ToDisk if possible, or C<undef> if one cannot be provided.

=cut

sub param {
	my $class = shift;
	return shift if UNIVERSAL::isa(ref $_[0], 'Socialtext::URI::ToDisk');
	return Socialtext::URI::ToDisk->new(@_) if @_ == 2;
	if ( ref $_[0] eq 'ARRAY' and @{$_[0]} ) {
		return Socialtext::URI::ToDisk->new(@{$_[0]});
	}
	undef;
}





#####################################################################
# Accessors

=pod

=head2 uri

The C<uri> method gets and returns the current URI path of the
location, in string form.

=cut

sub uri {
	$_[0]->{uri};
}

=pod

=head2 path

The C<path> method returns the filesystem path componant of the location.

=cut

sub path { $_[0]->{path} }





#####################################################################
# Manipulate Locations

=pod

=head2 catdir 'dir', 'dir', ...

A L<File::Spec> workalike, the C<catdir> method acts in the same way as for
L<File::Spec>, modifying both componants of the location. The C<catdir> method
returns a B<new> Socialtext::URI::ToDisk object representing the new location, or
C<undef> on error.

=cut

sub catdir {
	my $self = shift;
	my @args = @_;

	# Alter the URI and local paths
	my $new_uri  = File::Spec::Unix->catdir( $self->{uri}, @args ) or return undef;
	my $new_path = File::Spec->catdir( $self->{path}, @args )      or return undef;

	# Clone and set the new values
	my $changed = $self->clone;
	$changed->{uri}  = $new_uri;
	$changed->{path} = $new_path;

	$changed;
}

=pod

=head2 catfile [ 'dir', ..., ] $file

Like C<catdir>, the C<catfile> method acts in the same was as for 
L<File::Spec>, and returns a new Socialtext::URI::ToDisk object representing 
the file, or C<undef> on error.

=cut

sub catfile {
	my $self = shift;
	my @args = @_;

	# Alter the URI and local paths
	my $uri = File::Spec::Unix->catfile( $self->{uri}, @args ) or return undef;
	my $fs  = File::Spec->catfile( $self->{path}, @args )      or return undef;

	# Set both and return
	my $changed = $self->clone;
	$changed->{uri}  = $uri;
	$changed->{path} = $fs;

	$changed;
}


sub clone {
    my $self = shift;

    return bless { path => $self->path, uri => $self->uri }, ref $self;
}



#####################################################################
# Additional Overload Methods

sub __eq {
	my $left  = UNIVERSAL::isa(ref $_[0], 'Socialtext::URI::ToDisk') ? shift : return '';
	my $right = UNIVERSAL::isa(ref $_[0], 'Socialtext::URI::ToDisk') ? shift : return '';
	($left->path eq $right->path) and ($left->uri eq $right->uri);
}



1;

=pod

=head1 TO DO

Add more File::Spec-y methods as needed. Ask if you need one.

=head1 SUPPORT

Bugs should be reported via the CPAN bug tracker at

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=URI-ToDisk>

For other issues, or commercial enhancement or support, contact the author.

=head1 AUTHORS

Adam Kennedy L<http://ali.as/>, cpan@ali.as

=head1 COPYRIGHT

Copyright (c) 2003 - 2005 Adam Kennedy. All rights reserved.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

1;
