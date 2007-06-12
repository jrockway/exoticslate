# @COPYRIGHT@
package Socialtext::CredentialsExtractor;
use strict;
use warnings;

use Socialtext::AppConfig;
use Socialtext::MultiCursor;
use base qw( Socialtext::MultiPlugin );

sub base_package {
    return __PACKAGE__;
}

sub _drivers {
    my $class = shift;
    my $drivers = Socialtext::AppConfig->credentials_extractors();
    my @drivers = split /:/, $drivers;
    return @drivers;
}

sub Extractors {
    my $class = shift;

    return Socialtext::MultiCursor->new(
        iterables => [ [ $class->_drivers ] ],
        apply     => sub {
            my $driver = shift;
            return $class->_realize( $driver, 'extract_credentials' );
        }
    );
}

sub ExtractCredentials {
    my $class = shift;

    return $class->_first('extract_credentials', @_);
}

1;

__END__

=head1 NAME

Socialtext::CredentialsExtractor - a pluggable mechanism for extracting
credentials from a Request

=head1 SYNOPSIS

  use Socialtext::CredentialsExtractor;

  my $extractors = Socialtext::CredentialsExtractor->Extractors;
  my $credentials;

  while ( my $extractor = $extractors->next ) {

    $credentials = $extractor->extract_credentials( $request );

    ...
  }

  die "No creds, can't do anything" if !$credentials;

=head1 DESCRIPTION

This class provides a hook point for registering new means of gathering
credentials from a request object. 

=head1 METHODS

=head2 Socialtext::CredentialsExtractor->Extractors

Returns an iterable object comprising all the registered plugins in order of
their configuration (found as a setting in C<Socialtext::AppConfig>.

=head2 Socialtext::CredentialsExtractor->ExtractCredentials

Returns the first defined set of credentials it can.

Individual plugin classes are expected to implement a method called
'extract_credentials' which returns a scalar, either username or user_id.

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Socialtext, Inc., All Rights Reserved.

=cut
