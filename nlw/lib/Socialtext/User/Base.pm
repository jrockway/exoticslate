package Socialtext::User::Base;
# @COPYRIGHT@
use strict;
use warnings;

use Class::Field qw(field);
use Readonly;
use Socialtext::SQL qw(sql_parse_timestamptz);
use Socialtext::Validate qw(validate SCALAR_TYPE);
use Socialtext::l10n qw(loc);

# All fields/attributes that a "Socialtext::User::*" has.
Readonly our @fields => qw(
    user_id
    username
    email_address
    first_name
    last_name
    password
);
Readonly our @other_fields => qw(
    driver_key
    driver_unique_id
    cached_at
);
Readonly our @all_fields => (@fields, @other_fields);

# set up our fields
map { field $_ } @all_fields;

sub new {
    my $class = shift;

    # SANITY CHECK; have inbound parameters
    return unless @_;

    # instantiate based on given parameters (as HASH or HASH-REF)
    my $self = (@_ > 1) ? {@_} : $_[0];
    bless $self, $class;

    if (!$self->{cached_at}) {
        warn "no cached_at";
        return;
    }
    if (!ref($self->{cached_at})) {
        $self->{cached_at} = sql_parse_timestamptz($self->{cached_at});
    }

    return $self;
}

sub driver_name {
    my $self = shift;
    my ($name, $id) = split /:/, $self->driver_key();
    return $name;
}

sub driver_id {
    my $self = shift;
    my ($name, $id) = split /:/, $self->driver_key();
    return $id;
}

sub to_hash {
    my $self = shift;
    my $hash = {};
    foreach my $name (@fields) {
        my $value = $self->{$name};
        $hash->{$name} = "$value";  # to_string on some objects
    }
    return $hash;
}

# Removes all traces of the user from the users table
sub delete {
    my $self = shift;
    require Socialtext::User::Factory;  # avoid circular "use" dependency
    return Socialtext::User::Factory->DeleteUserRecord(
        @_, 
        user_id => $self->user_id
    );
}

# Expires the user, so that any cached data is no longer considered fresh.
sub expire {
    my $self = shift;
    require Socialtext::User::Factory;  # avoid circular "use" dependency
    return Socialtext::User::Factory->ExpireUserRecord(
        user_id => $self->user_id
    );
}

# Validates passwords, to make sure that they are of required length.
{
    Readonly my $spec => { password => SCALAR_TYPE };
    sub ValidatePassword {
        my $class = shift;
        my %p = validate( @_, $spec );

        return ( loc("Passwords must be at least 6 characters long.") )
            unless length $p{password} >= 6;

        return;
    }
}

1;

=head1 NAME

Socialtext::User::Base - Base class for User objects

=head1 DESCRIPTION

C<Socialtext::User::Base> implements a base class from which all User objects
are to be derived from.

=head1 METHODS

=over

=item B<Socialtext::User::*-E<gt>new($data)>

Creates a new user object based on the provided C<$data> (which could be a HASH
or a HASH-REF of data).

=item B<user_id()>

Returns the ID for the user.

=item B<username()>

Returns the username for the user.

=item B<email_address()>

Returns the e-mail address for the user, in all lower-case.

=item B<first_name()>

Returns the first name for the user.

=item B<last_name()>

Returns the last name for the user.

=item B<password()>

Returns the encrypted password for this user.

=item B<driver_name()>

Returns the name of the driver used for the data store this user was found in.
e.g. "Default", "LDAP".

=item B<driver_id()>

Returns the unique ID for the instance of the data store this user was found
in.  This unique ID is internal and likely has no meaning to a user.
e.g. "0deadbeef0".

=item B<driver_key()>

Returns the fully qualified driver key ("name:id") of the driver instance for
the data store this user was found in.  This key is internal and likely has no
meaning to a user.  e.g. "LDAP:0deadbeef0".

=item B<driver_unique_id()>

Returns the driver-specific unique identifier for this user.  This field is
internal and likely has no meaning to a user.
e.g. "cn=Bob,ou=Staff,dc=socialtext,dc=net"

=item B<to_hash()>

Returns a hash reference representation of the user, suitable for using with
JSON, YAML, etc.  B<WARNING:> The encrypted password is included in this hash,
and should usually be removed before passing the hash over the threshold.

=item B<new_from_hash()>

Create a new homunculus from a hash-ref of parameters.  Uses the C<driver_key>
to determine the class of the homunculus.

=item B<delete()>

Obliterates the user record for this homunculus from the system.

B<DANGER:> In almost all cases, users should B<not> be deleted as there are
foreign keys for far too many other tables, and even if a user is no longer
active they are still likely needed when looking up page authors, history, or
other information.

If you pass C<< force => 1 >> this will force the deletion though.

=item B<expire()>

Expires this user in the database.  May be a no-op for some homunculus types.

=item B<Socialtext::User::Base-E<gt>ValidatePassword(password=E<gt>$password)>

Validates the given password, returning a list of error messages if the
password is invalid.

=back

=head1 AUTHOR

Socialtext, Inc., C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2008 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
