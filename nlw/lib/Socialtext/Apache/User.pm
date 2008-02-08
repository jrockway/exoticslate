# @COPYRIGHT@
package Socialtext::Apache::User;

use strict;
use warnings;

use Apache::Cookie;
use Digest::SHA1 ();
use Socialtext::AppConfig;
use Socialtext::CredentialsExtractor;
use Socialtext::User;

use constant COOKIE_NAME => 'NLW-user';

# Note: A parallel version of this code lives in Socialtext::CGI::User
# so if this mechanism changes, we need to change the CGI version too
# (or merge them together).


sub set_login_cookie {
    my $r = shift;
    my $id = shift;
    my $expire = shift;

    my $value = { user_id => $id,
                  MAC     => _MAC_for_user_id($id),
                };

    _login_cookie( $r, $value, $expire );
}


sub unset_login_cookie {
    my $r = shift;

    _login_cookie( $r, '', '-1M' );
}

sub _login_cookie {
    my $r = shift;
    my $value = shift;
    my $expire = shift;

    _set_cookie( $r, COOKIE_NAME, $value, $expire );
}

sub current_user {
    my $r = shift;
    my $name_or_id = _user_id_or_username( $r ) or return;

    my $user = _current_user($name_or_id);
    $r->connection->user($user->username) unless $r->connection->user();
    return $user;
}

sub _current_user {
    my $name_or_id = shift;

    if ($name_or_id =~ /\D+/) {
        return Socialtext::User->new( username => $name_or_id );
    }
    else {
        return Socialtext::User->new( user_id => $name_or_id );
    }
}

sub _user_id_or_username {
    my $request = shift;

    if ( $ENV{SET_GENERIC_USER} ) {
        $request->connection->user($ENV{SET_GENERIC_USER});
        return $ENV{SET_GENERIC_USER};
    }

    return Socialtext::CredentialsExtractor->ExtractCredentials($request);
}

sub _MAC_for_user_id {
    return Digest::SHA1::sha1_base64( $_[0], Socialtext::AppConfig->MAC_secret );
}

sub _set_cookie {
    my $r = shift;
    my $name = shift;
    my $value = shift;
    my $expires = shift;

    Apache::Cookie->new
        ( $r,
          -name    => $name,
          -value   => $value,
          -expires => $expires,
          -path    => '/',
          ( Socialtext::AppConfig->cookie_domain ?
            ( -domain  => '.' . Socialtext::AppConfig->cookie_domain ) :
            ()
          ),
        )->bake;
}


1;

__END__

=head1 NAME

Socialtext::Apache::User - The great new Socialtext::Apache::User!

=head1 SYNOPSIS

  my $user_id = Socialtext::Apache::User::user_id($r);
  Socialtext::Apache::User::set_login_cookie( ... );

=head1 AUTHOR

Socialtext, Inc., C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2005 Socialtext, Inc. All Rights Reserved.

=cut
