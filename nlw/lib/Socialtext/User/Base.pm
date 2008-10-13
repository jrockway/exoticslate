package Socialtext::User::Base;
# @COPYRIGHT@

use strict;
use warnings;
use Class::Field qw(field);
use Readonly;
use Socialtext::SQL qw(sql_execute);

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
field 'driver_key';

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
    my $self = shift;
    my $p = shift;

    # create a copy of the parameters for our new User homunculus object
    my %user = map { $_ => $p->{$_} } @fields, 'driver_key';

    # bless the user object to the right class
    my ($driver_name, $driver_id) = split( /:/, $p->{driver_key} );
    my $driver_class = join '::', Socialtext::User->base_package, $driver_name;
    eval "require $driver_class";
    die "Couldn't load $driver_class: $@" if $@;

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

# Removes traces of the user from the "user_detail" table.
sub delete {
    my $self = shift;
    my $user_id_obj = Socialtext::UserId->new(
        driver_key          => $self->driver_key,
        driver_unique_id    => $self->user_id,
    );
    unless ($user_id_obj) {
        die "can't find UserId for user; did you delete the UserId first?";
    }
    sql_execute('DELETE FROM user_detail WHERE user_id=?', $user_id_obj->user_id);
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

=item B<to_hash()>

Returns a hash reference representation of the user, suitable for using with
JSON, YAML, etc.  B<WARNING:> The encrypted password is included in this hash,
and should usually be removed before passing the hash over the threshold.

=back

=head1 AUTHOR

Socialtext, Inc., C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2008 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
