# @COPYRIGHT@
package Socialtext::File::Stringify;
use strict;
use warnings;

use MIME::Types;
use Socialtext::File::Stringify::Default;
use Socialtext::Encode;

sub to_string {
    my ( $class, $filename, $type ) = @_;
    return "" unless defined $filename;
    my $convert_class = $class->_get_converter_for_file( $filename, $type );
    my $text = $convert_class->to_string($filename);
    return Socialtext::Encode::ensure_is_utf8($text);
}

sub _get_converter_for_file {
    my ( $class, $filename, $type ) = @_;
    $type ||= MIME::Types->new->mimeTypeOf($filename);
    return $class->_load_class_by_mime_type($type);
}

sub _load_class_by_mime_type {
    my ( $class, $type ) = @_;
    my $class_name = $type || "Default";
    $class_name =~ s{\W}{_}g;
    $class_name =~ s{_+}{_}g;
    $class_name = "Socialtext::File::Stringify::$class_name";
    eval "use $class_name;";
    return $@ ? "Socialtext::File::Stringify::Default" : $class_name;
}

1;
__END__

=pod

=head1 NAME

Socialtext::File::Stringify - Convert various file types to strings.

=cut

=head1 SUBROUTINES

=head2 to_string ( filename, [type] )

The file's MIME type is computed and used to dispatch to a specific method
that knows how to convert files of that type.  If type is passed in then it
overrides what MIME::Type would return.

=head1 SEE ALSO

L<MIME::Types>, L<Socialtext::File::Stringify::*>

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT

Copyright 2006 Socialtext, Inc., all rights reserved.

=cut
