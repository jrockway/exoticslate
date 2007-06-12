# @COPYRIGHT@
package Socialtext::CredentialsExtractor::BasicAuth;

use strict;
use warnings;

use Apache::Constants qw(OK);
use MIME::Base64;
use Readonly;
use Socialtext::Authen;

Readonly my $SERVICE => __PACKAGE__;

# REVIEW: we can test this with a mock request object
# XXX: much of this is cut and paste from
# Socialtext::Apache::AuthenHandler::check_basic
sub extract_credentials {
    my $class = shift;
    my $request = shift;

    my ( $username, $password );

    # XXX: Apache will only grant us access to $r->get_basic_pw() if we've
    # configured basic-auth in the config for the location, so roll our own.
    if (my $header = $request->header_in("Authorization")) {
        $header =~ s/\s*Basic\s+//;
        ($username, $password) = split(/:/, MIME::Base64::decode($header), 2);

        return $username
            if ( $username
            && $password
            && _authenticate_with( $request, $username, $password ) );
    }
    return undef;

}

sub _authenticate_with {
    my ($request, $username, $password) = @_;

    if ( $username eq '' ) {
        $request->log_reason( "$SERVICE - no username given", $request->uri );
        return 0;
    }
    elsif ( _authenticates( $username, $password ) ) {
        return 1;
    }

    $request->log_reason(
        "$SERVICE unable to authenticate $username for " . $request->uri );
    return 0;
}

sub _authenticates {
    my ( $username, $password ) = @_;

    my $auth = Socialtext::Authen->new();

    return (
        $auth->check_password(
            username => $username,
            password => $password,
        )
    );
}

1;

__END__

=head1 NAME

Socialtext::CredentialsExtractor::BasicAuth - a credentials extractor plugin

=head1 DESCRIPTION

This plugin class will return the username associated with the current
Apache Request object if that username is authentically provided by
HTTP Basic Auth.

=head1 METHODS

=head2 $extractor->extract_credentials( $request )

Return the user's username if it is present in a Basic Authorization header
along with the correct password for whatever authentication provider is
currently being configured by the system.

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Socialtext, Inc., All Rights Reserved.

=cut
