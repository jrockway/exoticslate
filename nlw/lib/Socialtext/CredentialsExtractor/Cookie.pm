# @COPYRIGHT@
package Socialtext::CredentialsExtractor::Cookie;

use strict;
use warnings;

use Apache::Cookie;
use Digest::SHA1;
use Socialtext::AppConfig;

use constant COOKIE_NAME => 'NLW-user';

sub extract_credentials {
    my $class = shift;
    my $request = shift;

    my %user_data = _get_cookie_value(COOKIE_NAME);

    return unless keys %user_data;

    my $mac = _MAC_for_user_id( $user_data{user_id} );

    unless ( $mac eq $user_data{MAC} ) {
        $request->log_reason(
            "Invalid MAC in cookie presented for $user_data{user_id}");
        return;
    }

    return $user_data{user_id};
}

sub _get_cookie_value {
    my $name = shift;

    my $cookies = Apache::Cookie->fetch;

    return unless $cookies;

    my $cookie = $cookies->{$name};

    return unless $cookie;

    return $cookie->value;
}

sub _MAC_for_user_id {
    return Digest::SHA1::sha1_base64( $_[0], Socialtext::AppConfig->MAC_secret );
}

1;

__END__

=head1 NAME

Socialtext::CredentialsExtractor::Cookie - a credentials extractor plugin

=head1 DESCRIPTION

This plugin class will look in the browser's provided cookies for 'NLW-user'
and attempt to extract and return a user_id from it.

=head1 METHODS

=head2 $extractor->extract_credentials( $request )

Return the value for the cookie 'NLW-user' or undef.

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Socialtext, Inc., All Rights Reserved.

=cut
