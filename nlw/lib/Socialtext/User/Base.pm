package Socialtext::User::Base;
# @COPYRIGHT@

use strict;
use warnings;
use Class::Field qw(field);
use Readonly;
use Socialtext::SQL qw(:exec :time);
use Socialtext::SQL::Builder qw(:all);
use Time::HiRes ();

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
    cached_at
);
map { field $_ } @other_fields;

our @all_fields = (@fields, @other_fields);

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

sub new_from_hash {
    my $class = shift;
    my $p = shift;

    # create a copy of the parameters for our new User homunculus object
    my %user = map { $_ => $p->{$_} } @all_fields;

    die "homunculi need to have a user_id, driver_key and driver_unique_id"
        unless ($user{user_id} && $user{driver_key} && $user{driver_unique_id});

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

# Expires the user, so that any cached data is no longer considered fresh.
sub expire {
    my $self = shift;
    sql_execute(q{
            UPDATE users 
            SET cached_at = '-infinity'
            WHERE user_id = ?
        }, $self->user_id);
}

# Class methods:

sub NewUserId {
    return sql_nextval('users___user_id');
}

sub ResolveId {
    my $class = shift;
    my $p = shift;
    my $user_id = sql_singlevalue(
        q{SELECT user_id FROM users 
          WHERE driver_key = ? AND driver_unique_id = ?},
        $p->{driver_key},
        $p->{driver_unique_id}
    );
}

sub _hires_dt_now {
    return DateTime->from_epoch(epoch => Time::HiRes::time());
}

sub GetUserRecord {
    my $class = shift;
    my $id_key = shift;
    my $id_val = shift;
    my $driver_key = shift;

    my $where;
    if ($id_key eq 'user_id' || $id_key eq 'driver_unique_id') {
        $where = $id_key;
    }
    elsif ($id_key eq 'username' || $id_key eq 'email_address') {
        $id_key = 'driver_username' if $id_key eq 'username';
        $id_val = Socialtext::String::trim(lc $id_val);
        $where = "LOWER($id_key)";
    }
    else {
        warn "invalid user ID lookup key '$id_key'";
        return undef;
    }


    my ($where_clause, @bindings);

    if ($where eq 'user_id') {
        # if we don't check this for being an integer here, the SQL query will
        # die.  Since looking up by a non-numeric user_id would return no
        # results, mimic that behaviour instead of throwing the exception.
        return undef if $id_val =~ /\D/;

        $where_clause = qq{user_id = ?};
        @bindings = ($id_val);
    }
    else {
        die "no driver key?!" unless $driver_key;
        my $search_deleted = (ref($driver_key) eq 'ARRAY');
        if (!$search_deleted) {
            $where_clause = qq{driver_key = ? AND $where = ?};
            @bindings = ($driver_key, $id_val);
        }
        else {
            die "no user factories configured?!" unless @$driver_key;
            my $placeholders = '?,' x @$driver_key;
            chop $placeholders;
            $where_clause = qq{driver_key NOT IN ($placeholders) AND $where=?};
            @bindings = (@$driver_key, $id_val);
            $driver_key = 'Deleted'; # if we get any results, make it Deleted
        }
    }

    my $sth = sql_execute(
        qq{SELECT * FROM users WHERE $where_clause},
        @bindings
    );

    my $row = $sth->fetchrow_hashref();
    return undef unless $row;

    # Always set this; the query returns the same value *except* when we're
    # looking for Deleted users.
    $row->{driver_key} = $driver_key;

    $row->{username} = delete $row->{driver_username};
    return $class->new_from_hash($row);
}

sub NewUserRecord {
    my $class = shift;
    my $proto_user = shift;

    $proto_user->{user_id} ||= $class->NewUserId();

    # always need a cached_at during INSERT, default it to 'now'
    $proto_user->{cached_at} = _hires_dt_now()
        if (!$proto_user->{cached_at} or 
            !ref($proto_user->{cached_at}) &&
            $proto_user->{cached_at} eq 'now');

    die "cached_at must be a DateTime object"
        unless (ref($proto_user->{cached_at}) && 
                $proto_user->{cached_at}->isa('DateTime'));

    my %insert_args = map { $_ => $proto_user->{$_} } @all_fields;

    $insert_args{driver_username} = $proto_user->{driver_username};
    delete $insert_args{username};

    $insert_args{cached_at} = 
        sql_format_timestamptz($proto_user->{cached_at});

    sql_insert('users' => \%insert_args);

    Socialtext::User::Cache->Clear();
}

sub UpdateUserRecord {
    my $class = shift;
    my $proto_user = shift;

    die "must have a user_id to update a user record"
        unless $proto_user->{user_id};
    die "must supply a cached_at parameter (undef means 'leave db alone')"
        unless exists $proto_user->{cached_at};

    $proto_user->{cached_at} = _hires_dt_now()
        if ($proto_user->{cached_at} && 
            !ref($proto_user->{cached_at}) &&
            $proto_user->{cached_at} eq 'now');

    my %update_args = map { $_ => $proto_user->{$_} } 
                      grep { exists $proto_user->{$_} }
                      @all_fields;

    if ($proto_user->{driver_username}) {
        $update_args{driver_username} = $proto_user->{driver_username};
    }
    delete $update_args{username};

    if (!$update_args{cached_at}) {
        # false/undef means "don't change cached_at in the db"
        delete $update_args{cached_at};
    }
    else {
        die "cached_at must be a DateTime object"
            unless (ref($proto_user->{cached_at}) && 
                    $proto_user->{cached_at}->isa('DateTime'));

        $update_args{cached_at} = 
            sql_format_timestamptz($update_args{cached_at});
    }

    sql_update('users' => \%update_args, 'user_id');

    Socialtext::User::Cache->Clear();
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

=item B<expire()>

Expires this user in the database.  May be a no-op for some homunculus types.

=back

=head2 CLASS METHODS

=over

=item B<NewUserId()>

Returns a new unique identifier for use in creating new users.

=item B<ResolveId(\%params)>

Class method.

Uses "driver_key" and "driver_unique_id" in the params argument to obtain the user_id corresponding to those values.

=item B<GetUserRecord($id_key,$id_val,$driver_key)>

Given an identifying key, it's value, and the driver key, return a
C<Socialtext::User::Base> homunculus.  For example, if given a 'Default'
driver key, the returned object will be a C<Socialtext::User::Default>
homunculus.

=item B<GetUserRecord($id_key,$id_val,$driver_key)>

Retrieves a new user record from the system database.

Given an identifying key, it's value, and the driver key, dip into the
database and return a C<Socialtext::User::Base> homunculus.  For example, if
given a 'Default' driver key, the returned object will be a
C<Socialtext::User::Default> homunculus.

If C<$id_key> is 'user_id', the C<$driver_key> is ignored; whatever is in the
database as the driver_key is used instead.

=item B<NewUserRecord(\%proto_user)>

Creates a new user record in the system database.

Uses the specified hashref to obtain the necessary values.

The 'cached_at' field must be a valid C<DateTime> object.  If it is missing or
set to the string "now", the current time (with C<Time::HiRes> accuracy) is
used.

If a user_id is not supplied, a new one will be created with C<NewUserId()>.

=item B<UpdateUserRecord(\%proto_user)>

Updates an existing user record in the system database.  A 'user_id' must be
present in the C<\%proto_user> argument for this update to work.

Uses the specified hashref to obtain the necessary values.  'user_id' cannot
be updated and will be silently ignored.

If the 'cached_at' parameter is undef, that field is left alone in the
database.  Otherwise, 'cached_at' must be a valid C<DateTime> object.  If it
is missing or set to the string "now", the current time (with C<Time::HiRes>
accuracy) is used.

Fields not specified by keys in the C<\%proto_user> will not be changed.  Any
keys who's value is undef will be set to NULL in the database.

=back

=head1 AUTHOR

Socialtext, Inc., C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2008 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
