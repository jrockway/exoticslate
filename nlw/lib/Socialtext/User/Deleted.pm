# @COPYRIGHT@
package Socialtext::User::Deleted;
use strict;
use warnings;

sub new {
    my $class = shift;

    return bless {
        @_,
        email_address => 'deleted.user@socialtext.com',
        first_name    => 'Deleted',
        last_name     => 'User'
    }, $class;

}

sub driver_name {
    return shift->{driver_key};
}

sub user_id {
    return shift->{user_id};
}

sub username {
    return shift->{username};
}

sub email_address {
    return shift->{email_address};
}

sub first_name {
    return shift->{first_name};
}

sub last_name {
    return shift->{last_name};
}

sub has_valid_password {
    # this is a deleted user, shouldn't have a valid password any longer.
    return 0;
}

sub password_is_correct {
    # this is a deleted user, shouldn't have a password that can be validated.
    return 0;
}

1;

__END__

=head1 NAME

Socialtext::User::Deleted - A Socialtext user object placeholder

=head1 SYNOPSIS

  use Socialtext::User::Deleted;

  my $user = Socialtext::User::Deleted->new( user_id => $user_id );

=head1 DESCRIPTION

This class provides methods for dealing with users that can no longer
be instantiated via their canonical drivers.

=head1 METHODS

=head2 Socialtext::User::Deleted->new(PARAMS)

Creates a satisfactory user matching PARAMS.

PARAMS should be:

=over 4

=item * user_id => $user_id

The original user_id associated with the deleted user's record. It was
unique within the driver's scope.

=item * username => $username

The username used the last time the deleted user logged into the system.

=item * driver_key => $driver_key

The original driver that had jurisdiction over the user.

=back

=head2 Socialtext::User::Deleted->driver_name()

Returns the name of the original driver that owned the deleted user.

=head2 Socialtext::User::Deleted->user_id()

Returns the original unique user_id the deleted user had within the
driver's scope.

=head2 Socialtext::User::Deleted->username()

Returns the original username the deleted user had within the driver's scope.

=head2 Socialtext::User::Deleted->email_address()

Since we don't cache email addresses for users, we give a default
email address.

=head2 Socialtext::User::Deleted->first_name()

Returns 'Deleted'.

=head2 Socialtext::User::Deleted->last_name()

Returns 'User'.

=head2 Socialtext::User::Deleted->has_valid_password()

Returns 0.

=head2 Socialtext::User::Deleted->password_is_correct()

Returns 0, no matter what is passed in.

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Socialtext, Inc., All Rights Reserved.

=cut
