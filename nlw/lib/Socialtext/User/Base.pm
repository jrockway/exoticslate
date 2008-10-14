package Socialtext::User::Base;
# @COPYRIGHT@

use strict;
use warnings;
use Class::Field qw(field);
use Readonly;
use Socialtext::SQL qw(sql_execute sql_singlevalue);

# all fields/attributes that a "User" has.
Readonly my @fields => qw(
    user_id
    username
    email_address
    first_name
    last_name
    password
    );
map { field $_ } @fields;

# additional fields.
Readonly my @other_fields => qw(
    driver_key
    driver_unique_id
);
map { field $_ } @other_fields;

sub new {
    my $class = shift;

    # SANITY CHECK; have inbound parameters
    return unless @_;

    # instantiate based on given parameters (as HASH or HASH-REF)
    my $self = (@_ > 1) ? {@_} : $_[0];
    bless $self, $class;
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

sub new_from_hash {
    my $class = shift;
    my $p = shift;

    # create a copy of the parameters for our new User homunculus object
    my %user = map { $_ => $p->{$_} } @fields, @other_fields;

    die "must have user_id and driver_unique_id"
        unless ($user{user_id} && $user{driver_unique_id});

    # bless the user object to the right class
    my ($driver_name, $driver_id) = split( /:/, $p->{driver_key} );
    my $driver_class = join '::', Socialtext::User->base_package, $driver_name;
    eval "require $driver_class";
    die "Couldn't load ${driver_class}: $@" if $@;

    my $homunculus = $driver_class->new(\%user);

    # Remove password fields for users, where the password is over-ridden by
    # the User driver (Default, LDAP, etc) and where the resulting password is
    # *NOT* of any use.  No point keeping a bunk/bogus/useless password
    # around.
    if ($homunculus->password eq '*no-password*') {
        if ($p->{password} && ($p->{password} ne $homunculus->password)) {
            delete $homunculus->{password};
        }
    }

    # return the new homunculus; we're done.
    return $homunculus;
}

# Removes traces of the user from the users table
sub delete {
    my $self = shift;
    sql_execute('DELETE FROM users WHERE user_id = ?', $self->user_id);
}

sub NewUserId {
    my $id = sql_singlevalue(q{SELECT nextval('users___user_id')});
    return $id;
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

B<DANGER:> In almost all cases, users should B<not> be deleted as there are
foreign keys for far too many other tables, and even if a user is no longer
active they are still likely needed when looking up page authors, history, or
other information.

If you pass C<< force => 1 >> this will force the deletion though.

=item B<NewUserId()>

Returns a new unique identifier for use in creating new users.

=back

=head1 AUTHOR

Socialtext, Inc., C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2008 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
