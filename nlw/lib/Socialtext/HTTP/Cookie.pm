package Socialtext::HTTP::Cookie;

###############################################################################
# Required inclusions.
use strict;
use warnings;
use Digest::SHA1 qw(sha1_base64);
use Socialtext::AppConfig;

###############################################################################
# Allow some constant values to be exported
use base qw(Exporter);
our %EXPORT_TAGS = (
    constants => [qw( USER_DATA_COOKIE )],
    );
our @EXPORT_OK = map { @{$_} } values %EXPORT_TAGS;

sub USER_DATA_COOKIE { 'NLW-user' };

###############################################################################
sub MAC_for_user_id {
    my ($class, $user_id) = @_;
    return sha1_base64( $user_id, Socialtext::AppConfig->MAC_secret );
}

1;

=head1 NAME

Socialtext::HTTP::Cookie - HTTP cookie interface

=head1 SYNOPSIS

  use Socialtext::HTTP::Cookie;

  # generate MAC for a User ID
  $mac = Socialtext::HTTP::Cookie->MAC_for_user_id($user_id);

=head1 DESCRIPTION

C<Socialtext::HTTP::Cookie> provides several methods to assist in the handling
of HTTP cookies.

Before C<Socialtext::HTTP::Cookie>, these methods were scattered around the
code, and some had multiple implementations.

=head1 CONSTANTS

The following constants are available for import either via the C<:constants>
tag (if you want all of them) or by importing them individually:

=over

=item USER_DATA_COOKIE

The name of the HTTP cookie that contains User Authentication information
(NLW-user).

=back

=head1 METHODS

=over

=item B<Socialtext::HTTP::Cookie-E<gt>MAC_for_user_id($user_id)>

Generates a MAC based on the given C<$user_id>, and returns the MAC back to
the caller.

=back

=head1 AUTHOR

Socialtext, Inc.  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2008 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
