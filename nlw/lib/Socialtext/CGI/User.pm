package Socialtext::CGI::User;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Exporter';
our @EXPORT_OK = qw/get_current_user/;
use Digest::SHA1;
use CGI::Cookie;
use Socialtext::Apache::User;
use Socialtext::HTTP::Cookie qw(USER_DATA_COOKIE);

# Note: A parallel version of this code lives in Socialtext::Apache::User
# so if this mechanism changes, we need to change the CGI version too
# (or merge them together).
# This one is used by reports and the appliance console

sub get_current_user {
    my $name_or_id = _user_id_or_username() || return;
    return Socialtext::Apache::User::_current_user($name_or_id);
}

sub _user_id_or_username {
    my %user_data = _get_cookie_value(USER_DATA_COOKIE);
    return unless keys %user_data;

    my $mac = Socialtext::HTTP::Cookie->MAC_for_user_id( $user_data{user_id} );
    unless ($mac eq $user_data{MAC}) {
        warn "Invalid MAC in cookie presented for $user_data{user_id}\n";
        return;
    }

    return $user_data{user_id};
}

sub _get_cookie_value {
    my $name = shift;
    my $cookies = CGI::Cookie->raw_fetch;
    my $value = $cookies->{$name};
    my %user_data = split(/[&;]/, $value);
    return %user_data;
}

1;

=head1 NAME

Socialtext::CGI::User - Extract Socialtext user information from a CGI request

=head1 AUTHOR

Socialtext, Inc., C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Socialtext, Inc. All Rights Reserved.

=cut
