package Socialtext::User::Factory;
# @COPYRIGHT@
use strict;
use warnings;

use Class::Field qw(field);
use Socialtext::SQL qw(:exec :time);
use Socialtext::SQL::Builder qw(:all);
use Socialtext::User::Cache;
use Socialtext::Exceptions qw( data_validation_error );
use Socialtext::UserMetadata;
use Socialtext::String;
use Socialtext::User::Base;
use Socialtext::User::Default;
use Socialtext::User::Default::Users qw(:system-user :guest-user);
use Socialtext::l10n qw(loc);
use Email::Valid;
use Readonly;
use Time::HiRes ();

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
    return DateTime->from_epoch(epoch => Time::HiRes::time());
}

sub GetHomunculus {
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
    return $class->NewHomunculus($row);
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

# Validates User data, and cleans it up where appropriate.  If the data isn't
# valid, this method throws a Socialtext::Exception::DataValidation exception.
{
    Readonly my @required_fields   => qw(username email_address);
    Readonly my @lowercased_fields => qw(username email_address);
    sub ValidateAndCleanData {
        my $self = shift;
        my $user = shift;
        my $p = shift;
        my $metadata;
        my @errors;

        # are we validating for the "creation of a new user", or for "updating
        # an existing user" ?
        my $is_create = defined $user ? 0 : 1;

        # if we're creating a new User, make sure that he's got a "user_id"
        if ($is_create) {
            $p->{user_id} ||= $self->NewUserId();
        }

        # if we're updating an existing User, make sure that we've got a copy
        # of their metadata; we'll need it later.
        if (not $is_create) {
            $metadata = Socialtext::UserMetadata->new(
                user_id => $user->user_id
            );
        }

        # Lower-case any fields that require it
        map { $p->{$_} = lc($p->{$_}) }
            grep { defined $p->{$_} }
            @lowercased_fields;

        # Check for required fields, and make sure that they're not in use by
        # another User record right now.
        foreach my $field_name (@required_fields) {
            # trim the field, removing leading/trailing spaces
            if (defined $p->{$field_name}) {
                $p->{$field_name}
                    = Socialtext::String::trim($p->{$field_name});
            }

            # make sure we have a value for this; its a *required* field
            if (exists $p->{$field_name} or $is_create) {
                unless (defined $p->{$field_name} and length($p->{$field_name})) {
                    push @errors,
                        loc('[_1] is a required field.',
                            ucfirst Socialtext::Data::humanize_column_name($field_name)
                        );
                }
            }

            # make sure that we've got a unique value, and its not in use by
            # any other User records
            if (defined $p->{$field_name}) {
                my $field_value = $p->{$field_name};

                # if we're creating a new User, *or* we're changing the value
                # in an existing User
                if ($is_create or ($field_value ne $user->$field_name())) {

                    # make sure there isn't an existing User with that value
                    if (Socialtext::User->new_homunculus($field_name => $field_value)) {
                        push @errors,
                            loc("The [_1] you provided ([_2]) is already in use.",
                                Socialtext::Data::humanize_column_name($field_name),
                                $field_value
                            );
                    }
                }
            }
        }

        # make sure that the e-mail address is valid
        if (defined $p->{email_address}
            and length $p->{email_address}
            and !Email::Valid->address($p->{email_address}))
        {
            push @errors,
                loc("[_1] is not a valid email address.",
                    $p->{email_address}
                );
        }

        # make sure that the password is valid
        if (defined $p->{password}) {
            my $password_error = Socialtext::User::Default->ValidatePassword(
                    password => $p->{password}
                );
            push @errors, $password_error if $password_error;
        }

        # if we're creating a new User, password could be required
        if (delete $p->{require_password}
            and $is_create
            and not defined $p->{password})
        {
            push @errors, loc('A password is required to create a new user.');
        }

        # there are certain things you just can't change on a system-created
        # User.
        if (!$is_create and $metadata and $metadata->is_system_created) {
            push @errors,
                loc("You cannot change the name of a system-created user.")
                if $p->{username};

            push @errors,
                loc("You cannot change the email address of a system-created user.")
                if $p->{email_address};
        }

        # if we found any errors, throw an exception.
        data_validation_error errors => \@errors if @errors;

        # if we're creating a new User and we weren't given a password, assign
        # a placeholder.
        if ($is_create
            and not(defined $p->{password} and length $p->{password}))
        {
            $p->{password} = '*none*';
            $p->{no_crypt} = 1;
        }

        # we don't care about different salt per-user - we crypt to
        # obscure passwords from ST admins, not for real protection (in
        # which case we would not use crypt)
        $p->{password} = Socialtext::User::Default->_crypt( $p->{password}, 'salty' )
            if exists $p->{password} && ! delete $p->{no_crypt};

        # unless we were told which User was creating this user, default it to
        # the system user.
        if ( $is_create and $p->{username} ne $SystemUsername ) {
            # this will not exist when we are making the system user!
            $p->{created_by_user_id} ||= Socialtext::User->SystemUser()->user_id;
        }
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
