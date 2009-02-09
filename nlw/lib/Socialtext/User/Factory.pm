package Socialtext::User::Factory;
# @COPYRIGHT@
use strict;
use warnings;

use Class::Field qw(field);
use Socialtext::Date;
use Socialtext::SQL qw(:exec :time);
use Socialtext::SQL::Builder qw(:all);
use Socialtext::User::Cache;
use Socialtext::Exceptions qw( data_validation_error );
use Socialtext::UserMetadata;
use Socialtext::String;
use Socialtext::Data;
use Socialtext::User::Base;
use Socialtext::User::Default;
use Socialtext::User::Default::Users qw(:system-user :guest-user);
use Socialtext::l10n qw(loc);
use Email::Valid;
use Readonly;

field 'driver_name';
field 'driver_id';
field 'driver_key';

sub new_homunculus {
    my $self = shift;
    my $p = shift;
    $p->{driver_key} = $self->driver_key;
    return $self->NewHomunculus($p);
}

sub get_homunculus {
    my $self = shift;
    my $id_key = shift;
    my $id_val = shift;
    return $self->GetHomunculus($id_key, $id_val, $self->driver_key);
}

sub NewHomunculus {
    my $class = shift;
    my $p = shift;

    # create a copy of the parameters for our new User homunculus object
    my %user = map { $_ => $p->{$_} } @Socialtext::User::Base::all_fields;

    die "homunculi need to have a user_id, driver_key and driver_unique_id"
        unless ($user{user_id} && $user{driver_key} && $user{driver_unique_id});

    # bless the user object to the right class
    my ($driver_name, $driver_id) = split( /:/, $p->{driver_key} );
    require Socialtext::User;
    my $driver_class = join '::', Socialtext::User->base_package, $driver_name;
    eval "require $driver_class";
    die "Couldn't load ${driver_class}: $@" if $@;

    my $homunculus = $driver_class->new(\%user);

    if ($p->{extra_attrs} && $homunculus->can('extra_attrs')) {
        $homunculus->extra_attrs($p->{extra_attrs});
    }

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

sub Now {
    return Socialtext::Date->now(hires=>1);
}

sub GetHomunculus {
    my $class = shift;
    my $id_key = shift;
    my $id_val = shift;
    my $driver_key = shift;
    my $return_raw_proto_user = shift || 0;

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
    return ($return_raw_proto_user) ? $row : $class->NewHomunculus($row);
}

sub NewUserRecord {
    my $class = shift;
    my $proto_user = shift;

    $proto_user->{user_id} ||= $class->NewUserId();

    # always need a cached_at during INSERT, default it to 'now'
    $proto_user->{cached_at} = $class->Now()
        if (!$proto_user->{cached_at} or 
            !ref($proto_user->{cached_at}) &&
            $proto_user->{cached_at} eq 'now');

    die "cached_at must be a DateTime object"
        unless (ref($proto_user->{cached_at}) && 
                $proto_user->{cached_at}->isa('DateTime'));

    my %insert_args
        = map { $_ => $proto_user->{$_} } @Socialtext::User::Base::all_fields;
    $insert_args{first_name} ||= '';
    $insert_args{last_name}  ||= '';

    $insert_args{driver_username} = $proto_user->{driver_username};
    delete $insert_args{username};

    $insert_args{cached_at} = 
        sql_format_timestamptz($proto_user->{cached_at});

    sql_insert('users' => \%insert_args);
}

sub UpdateUserRecord {
    my $class = shift;
    my $proto_user = shift;

    die "must have a user_id to update a user record"
        unless $proto_user->{user_id};
    die "must supply a cached_at parameter (undef means 'leave db alone')"
        unless exists $proto_user->{cached_at};

    $proto_user->{cached_at} = $class->Now()
        if ($proto_user->{cached_at} && 
            !ref($proto_user->{cached_at}) &&
            $proto_user->{cached_at} eq 'now');

    my %update_args = map { $_ => $proto_user->{$_} } 
                      grep { exists $proto_user->{$_} }
                      @Socialtext::User::Base::all_fields;

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

    # flush cache; updated User in DB
    Socialtext::User::Cache->Remove( user_id => $proto_user->{user_id} );
}

sub ExpireUserRecord {
    my $self = shift;
    my %p = @_;
    return unless $p{user_id};
    sql_execute(q{
            UPDATE users 
            SET cached_at = '-infinity'
            WHERE user_id = ?
        }, $p{user_id});
    Socialtext::User::Cache->Remove( user_id => $p{user_id} );
}

# Validates a hash-ref of User data, cleaning it up where appropriate.  If the
# data isn't valid, this method throws a Socialtext::Exception::DataValidation
# exception.
{
    Readonly my @required_fields   => qw(username email_address);
    Readonly my @unique_fields     => qw(username email_address);
    Readonly my @lowercased_fields => qw(username email_address);
    sub ValidateAndCleanData {
        my ($self, $user, $p) = @_;
        my @errors;
        my @buffer;

        # are we "creating a new user", or "updating an existing user"?
        my $is_create = defined $user ? 0 : 1;

        # New user's *have* to have a User Id
        $self->_validate_assign_user_id($p) if ($is_create);

        # When updating a User, we'll need their Metadata
        my $metadata;
        unless ($is_create) {
            $metadata = Socialtext::UserMetadata->new(
                user_id => $user->{user_id},
            );
        }

        # Lower-case any fields that require it
        $self->_validate_lowercase_values($p);

        # Trim fields, removing leading/trailing whitespace
        $self->_validate_trim_values($p);

        # Check for presence of required fields
        foreach my $field (@required_fields) {
            # field is required if either (a) we're creating a new User
            # record, or (b) we were given a value to update with
            if ($is_create or exists $p->{$field}) {
                @buffer = $self->_validate_check_required_field($field, $p);
                push @errors, @buffer if (@buffer);
            }
        }

        # Make sure that unique fields are in fact unique
        foreach my $field (@unique_fields) {
            # value has to be unique if either (a) we're creating a new User,
            # or (b) we're changing the value for an existing User.
            if (defined $p->{$field}) {
                if ($is_create or ($p->{$field} ne $user->{$field})) {
                    @buffer = $self->_validate_check_unique_value($field, $p);
                    push @errors, @buffer if (@buffer);
                }
            }
        }

        # Ensure that any provided e-mail address is valid
        @buffer = $self->_validate_email_is_valid($p);
        push @errors, @buffer if (@buffer);

        # Ensure that any provided password is valid
        @buffer = $self->_validate_password_is_valid($p);
        push @errors, @buffer if (@buffer);

        # When creating a new User, we MAY require that a password be provided
        if (delete $p->{require_password} and $is_create) {
            @buffer = $self->_validate_password_is_required($p);
            push @errors, @buffer if (@buffer);
        }

        # Can't change the username/email for a system-created User
        if (!$is_create and $metadata and $metadata->is_system_created) {
            push @errors,
                loc("You cannot change the name of a system-created user.")
                if $p->{username};

            push @errors,
                loc("You cannot change the email address of a system-created user.")
                if $p->{email_address};
        }

        ### IF DATA FAILED TO VALIDATE, THROW AN EXCEPTION!
        if (@errors) {
            data_validation_error errors => \@errors;
        }

        # when creating a new User, assign a placeholder password unless one
        # was provided.
        $self->_validate_assign_placeholder_password($p) if ($is_create);

        # encrypt any provided password
        $self->_validate_encrypt_password($p);

        # ensure that we're noting who created this User
        $self->_validate_assign_created_by($p) if ($is_create);

    }

    sub _validate_assign_user_id {
        my ($self, $p) = @_;
        $p->{user_id} ||= $self->NewUserId();
        return;
    }
    sub _validate_lowercase_values {
        my ($self, $p) = @_;
        map { $p->{$_} = lc($p->{$_}) }
            grep { defined $p->{$_} }
            @lowercased_fields;
        return;
    }
    sub _validate_trim_values {
        my ($self, $p) = @_;
        map { $p->{$_} = Socialtext::String::trim($p->{$_}) }
            grep { defined $p->{$_} }
            @Socialtext::User::Base::all_fields;
        return;
    }
    sub _validate_check_required_field {
        my ($self, $field, $p) = @_;
        unless ((defined $p->{$field}) and (length($p->{$field}))) {
            return loc('[_1] is a required field.',
                ucfirst Socialtext::Data::humanize_column_name($field)
            );
        }
        return;
    }
    sub _validate_check_unique_value {
        my ($self, $field, $p) = @_;
        my $value = $p->{$field};
        my $isnt_unique = Socialtext::User->_first('lookup', $field => $value);
        if ($isnt_unique) {
            # User lookup found _something_.
            # 
            # If what we found wasn't "us" (the User data we're checking for
            # unique-ness), fail.
            my $driver_uid   = $p->{driver_unique_id};
            my $existing_uid = $isnt_unique->{driver_unique_id};
            if (!$driver_uid || ($driver_uid ne $existing_uid)) {
                return loc("The [_1] you provided ([_2]) is already in use.",
                        Socialtext::Data::humanize_column_name($field), $value
                    );
            }
        }
        return;
    }
    sub _validate_email_is_valid {
        my ($self, $p) = @_;
        my $email = $p->{email_address};
        if (defined $email) {
            unless (length($email) and Email::Valid->address($email)) {
                return loc("[_1] is not a valid email address.", $email);
            }
        }
        return;
    }
    sub _validate_password_is_valid {
        my ($self, $p) = @_;
        my $password = $p->{password};
        if (defined $password) {
            return Socialtext::User::Default->ValidatePassword(
                password => $password,
            );
        }
        return;
    }
    sub _validate_password_is_required {
        my ($self, $p) = @_;
        unless (defined $p->{password}) {
            return loc('A password is required to create a new user.');
        }
        return;
    }
    sub _validate_assign_placeholder_password {
        my ($self, $p) = @_;
        my $password = $p->{password};
        unless (defined $password and length($password)) {
            $p->{password} = '*none*';
            $p->{no_crypt} = 1;
        }
        return;
    }
    sub _validate_encrypt_password {
        my ($self, $p) = @_;
        if ((exists $p->{password}) and (not delete $p->{no_crypt})) {
            # NOTE: doesn't matter if we have/use a different salt per-user;
            # we're encrypting to obscure passwords from ST admins, not for
            # _real_ protection (in which case we wouldn't be using 'crypt()'
            # in the first place).
            $p->{password} =
                Socialtext::User::Default->_crypt( $p->{password}, 'salty' );
        }
        return;
    }
    sub _validate_assign_created_by {
        my ($self, $p) = @_;
        if ($p->{username} ne $SystemUsername) {
            # unless we were told who is creating this User, presume that it's
            # being created by the System-User.
            $p->{created_by_user_id} ||= Socialtext::User->SystemUser()->user_id;
        }
        return;
    }
}

1;

=head1 NAME

Socialtext::User::Factory - Abstract base class for User factories.

=head1 DESCRIPTION

C<Socialtext::User::Factory> provides class methods that factories should use when retrieving/storing users in the system database.

Subclasses of this module *MUST* be named C<Socialtext::User::${driver_name}::Factory>

A "Driver" is the code used to instantiate Homunculus objects.  A "Factory" is an instance of a driver (C<Socialtext::User::LDAP::Factory> can have multiple factories configured, while C<Socialtext::User::Default::Factory> can only have one instance).

=head1 METHODS

=over

=item B<driver_name()>

The driver_name is a name that identifies this factory class.  Code will use
this name to initialize a driver instance ("factory").

=item B<driver_id()>

Returns the unique ID for the instance of the data store ("factory") this user
was found in.  This unique ID is internal and likely has no meaning to a user.
e.g. "0deadbeef0".

=item B<driver_key()>

Returns the fully qualified driver key in the form ("name:id") of this factory (driver instance).

The database will use this key to map users to their owning factories.  This
key is internal and likely has no meaning to an end-user.  e.g.
"LDAP:0deadbeef0".

=item B<new_homunculus(\%proto_user)>

Calls C<NewHomunculus(\%proto_user)>, overriding the driver_key field of the proto_user with the result of C<$self->driver_key>.

=item B<get_homunculus($id_key => $id_val)>

Calls C<GetHomunculus()>, passing in the driver_key of this factory.

=back

=head2 CLASS METHODS

=over

=item B<NewHomunculus(\%proto_user)>

Helper method that will instantiate a Homunculus based on the driver_key field
contained in the C<\%proto_user> hashref.

Homunculi need to have a user_id, driver_key and driver_unique_id to be created.

=item B<NewUserId()>

Returns a new unique identifier for use in creating new users.

=item B<ResolveId(\%params)>

Attempts to resolve the C<user_id> for the User represented by the given
C<\%params>.

Resolution is limited to B<just> the C<driver_key> specified in the params;
we're I<not> doing cross-driver resolution.

Default implementation here attempts resolution by looking for a matching
C<driver_unique_id>.

=item B<Now()>

Creates a DateTime object with the current time from C<Time::HiRes::time> and
returns it.

=item B<GetHomunculus($id_key,$id_val,$driver_key)>

Retrieves a new user record from the system database and uses C<NewHomunculus()> to instantiate it.

Given an identifying key, it's value, and the driver key, dip into the
database and return a C<Socialtext::User::Base> homunculus.  For example, if
given a 'Default' driver key, the returned object will be a
C<Socialtext::User::Default> homunculus.

If C<$id_key> is 'user_id', the C<$driver_key> is ignored as a parameter.

=item B<NewUserRecord(\%proto_user)>

Creates a new user record in the system database.

Uses the specified hashref to obtain the necessary values.

The 'cached_at' field must be a valid C<DateTime> object.  If it is missing or
set to the string "now", the current time (with C<Time::HiRes> accuracy) is
used.

If a user_id is not supplied, a new one will be created with C<NewUserId()>.

=item B<UpdateUserRecord(\%proto_user)>

Updates an existing user record in the system database.  

A 'user_id' must be present in the C<\%proto_user> argument for this update to
work.

Uses the specified hashref to obtain the necessary values.  'user_id' cannot
be updated and will be silently ignored.

If the 'cached_at' parameter is undef, that field is left alone in the
database.  Otherwise, 'cached_at' must be a valid C<DateTime> object.  If it
is missing or set to the string "now", the current time (with C<Time::HiRes>
accuracy) is used.

Fields not specified by keys in the C<\%proto_user> will not be changed.  Any
keys who's value is undef will be set to NULL in the database.

=item B<ExpireUserRecord(user_id => 42)>

Expires the specified user.

The `cached_at` field of the specified user is set to '-infinity' in the
database.

=item B<ValidateAndCleanData($user, \%p)>

Validates and cleans the given hashref of data, which I<may> be an update for
the provided C<$user> object.

If a C<Socialtext::User> object is provided for C<$user>, this method
validates the data as if we were performing an B<update> to the information in
that User object.

If no value is provided for C<$user>, this method validates the data as if we
were creating a B<new> User object.

On success, this method returns.  On validation error, it throws a
C<Socialtext::Exception::DataValidation> exception.

=back

=head1 AUTHOR

Socialtext, Inc., C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
