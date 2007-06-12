# @COPYRIGHT@
package Socialtext::CredentialsExtractor::Guest;

use strict;
use warnings;

sub extract_credentials {
    return undef;
}

1;

__END__

=head1 NAME

Socialtext::CredentialsExtractor::Guest - a credentials extractor plugin

=head1 DESCRIPTION

This plugin class will return undef to indicate no user was found.

=head1 METHODS

=head2 $extractor->extract_credentials( $request )

Return undef to indicate no user was found in the credentials and 
guest may be attempted.

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Socialtext, Inc., All Rights Reserved.

=cut

