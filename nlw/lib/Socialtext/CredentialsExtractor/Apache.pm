package Socialtext::CredentialsExtractor::Apache;
# @COPYRIGHT@

use strict;
use warnings;

sub extract_credentials {
    my ($class, $request) = @_;
    my $username = $request->connection->user();
    return $username;
}

1;

=head1 NAME

Socialtext::CredentialsExtractor::Apache - Apache validated credentials

=head1 DESCRIPTION

This plugin class trusts the credentials as validated by Apache; if Apache
says that the User has been able to log in then we trust that Authen has been
performed and we return the username for the logged in User.

=head1 METHODS

=over

=item B<$extractor-E<gt>extract_credentials($request)>

Returns the Username as previously authenticated by Apache.

=back

=head1 AUTHOR

Socialtext, Inc., C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
