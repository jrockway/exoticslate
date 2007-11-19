# @COPYRIGHT@
package Socialtext::User::Default;

use strict;
use warnings;

our $VERSION = '0.01';

use Socialtext::Exceptions qw( data_validation_error param_error );
use Socialtext::Validate qw( validate SCALAR_TYPE BOOLEAN_TYPE ARRAYREF_TYPE WORKSPACE_TYPE );

use Class::Field 'field';
use Digest::SHA1 ();
use Email::Valid;
use Socialtext::String;
use Readonly;
use Socialtext::Data;
use Socialtext::SQL 'sql_execute';
use Socialtext::User;
use Socialtext::UserId;
use Socialtext::UserMetadata;
use Socialtext::UserWorkspaceRole;
use Socialtext::l10n qw(loc);

field 'user_id';
field 'username';
field 'email_address';
field 'first_name';
field 'last_name';
field 'password';

my $SystemUsername = 'system-user';
my $GuestUsername  = 'guest';

sub table_name { 'User' }
sub driver_name { 'Default' }

# FIXME: This belongs elsewhere, in fixture generation code, perhaps
sub EnsureRequiredDataIsPresent {
    my $class = shift;

    unless ( $class->new( username => $SystemUsername ) ) {
        my $system_user = $class->create(
            username      => $SystemUsername,
            email_address => 'system-user@socialtext.net',
            first_name    => 'System',
            last_name     => 'User',
            password      => '*no-password*',
            no_crypt      => 1,
        );
        my $system_unique_id = Socialtext::UserId->create(
            driver_key       => 'Default',
            driver_unique_id => $system_user->user_id,
            driver_username  => $SystemUsername,
            )->system_unique_id;
        Socialtext::UserMetadata->create(
            user_id            => $system_unique_id,
            created_by_user_id => undef,
            is_system_created  => 1,
        );
    }

    unless ( $class->new( username => $GuestUsername ) ) {
        my $system_user = Socialtext::User->new( username => $SystemUsername );
        my $guest_user = $class->create(
            username      => $GuestUsername,
            email_address => 'guest@socialtext.net',
            first_name    => 'Guest',
            last_name     => 'User',
            password      => '*no-password*',
            no_crypt      => 1,
        );
        my $system_unique_id = Socialtext::UserId->create(
            driver_key       => 'Default',
            driver_unique_id => $guest_user->user_id,
            driver_username  => $GuestUsername,
            )->system_unique_id;
        Socialtext::UserMetadata->create(
            user_id            => $system_unique_id,
            created_by_user_id => $system_user->user_id,
            is_system_created  => 1,
        );
    }
}

sub Count {
    my ( $class, %p ) = @_;

    my $sth = sql_execute('SELECT COUNT(*) FROM "User"');
    return $sth->fetchall_arrayref->[0][0];
}

sub new {
    my ( $class, %p ) = @_;

    return
        exists $p{user_id} ? $class->_new_from_where( 'user_id', $p{user_id} )
            : exists $p{username} ? $class->_new_from_where(
                'LOWER(username)', _clean_username_or_email( lc $p{username} ) )
            : $class->_new_from_where(
                'LOWER(email_address)',
                _clean_username_or_email( lc $p{email_address} )
            );
}

sub _new_from_where {
    my ( $class, $where_clause, @bindings ) = @_;

    my $sth = sql_execute(
        'SELECT user_id, username, email_address,'
        . ' first_name, last_name, password'
        . ' FROM "User"'
        . " WHERE $where_clause=?",
        @bindings
    );
    my @rows = @{ $sth->fetchall_arrayref };
    return @rows ? bless {
                    user_id       => $rows[0][0],
                    username      => $rows[0][1],
                    email_address => $rows[0][2],
                    first_name    => $rows[0][3],
                    last_name     => $rows[0][4],
                    password      => $rows[0][5],
                    }, $class
                 : undef;
}

sub create {
    my ( $class, %p ) = @_;

    $class->_validate_and_clean_data(\%p);

    $p{first_name} ||= '';
    $p{last_name} ||= '';

    sql_execute(
        'INSERT INTO "User"'
        . ' (user_id, username, email_address, first_name, last_name, password)'
        . ' VALUES (nextval(\'"User___user_id"\'),?,?,?,?,?)',
        $p{username}, $p{email_address}, $p{first_name}, $p{last_name},
        $p{password}
    );

    return $class->new( username => $p{username} );
}

sub delete {
    my ( $self ) = @_;

    sql_execute( 'DELETE FROM "User" WHERE user_id=?', $self->user_id );
}

# "update" methods: generic update?
sub update {
    my ( $self, %p ) = @_;

    $self->_validate_and_clean_data(\%p);

    my ( @updates, @bindings );
    while (my ($column, $value) = each %p) {
        push @updates, "$column=?";
        push @bindings, $value;
    }

    my $set_clause = join ', ', @updates;

    sql_execute(
        'UPDATE "User"'
        . " SET $set_clause WHERE user_id=?",
        @bindings, $self->user_id);

    while (my ($column, $value) = each %p) {
        $self->$column($value);
    }

    return $self;
}

sub to_hash {
    my $self = shift;
    my $hash = {};
    foreach my $name
        qw( user_id username email_address first_name last_name password ) {
        my $value = $self->$name();
        $hash->{$name} = "$value";    # to_string on some objects
    }
    return $hash;
}

{
    Readonly my $spec => { password => SCALAR_TYPE };
    sub ValidatePassword {
        shift;
        my %p = validate( @_, $spec );

        return ( loc("Passwords must be at least 6 characters long.") )
            unless length $p{password} >= 6;

        return;
    }
}

sub has_valid_password {
    my $self = shift;

    return 1
        if $self->password ne '*none*';
}

sub password_is_correct {
    my $self = shift;
    my $pw   = shift;

    my $db_pw = $self->password;

    return $self->_crypt( Socialtext::String::trim($pw), $db_pw ) eq $db_pw;
}

# Required Socialtext::User plugin methods

sub Search {
    my $class = shift;
    my $search_term = shift;

    my $splat_term = lc "\%$search_term\%";

    my $sth = sql_execute(
        'SELECT first_name, last_name, email_address'
        . ' FROM "User" WHERE'
        . ' ( LOWER( username ) LIKE ? OR'
        . ' LOWER( email_address ) LIKE ? OR'
        . ' LOWER( first_name ) LIKE ? OR'
        . ' LOWER( last_name ) LIKE ? ) AND'
        . ' ( username NOT IN ? )',
        $splat_term, $splat_term, $splat_term, $splat_term,
        [ $SystemUsername, $GuestUsername ]
    );

    return Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref ],
        apply => sub {
            my $row = shift;
            my $name = Socialtext::User->FormattedEmail(@$row);
            return {
                driver_name    => $class->driver_name,
                email_address  => $row->[2],
                name_and_email => $name,
            };
        },
    )->all;
}

# Helper methods

sub _validate_and_clean_data {
    my $self = shift;
    my $p = shift;
    my $metadata;

    my $is_create = ref $self ? 0 : 1;

    if (not $is_create) {
        my $system_unique_id = Socialtext::UserId->new(
            driver_key => 'Default',
            driver_unique_id => $self->user_id
        )->system_unique_id;
        $metadata = Socialtext::UserMetadata->new(
            user_id => $system_unique_id
        );
    }

    my @errors;
    for my $k ( qw( username email_address ) ) {
        $p->{$k} = Socialtext::String::trim( lc $p->{$k} )
            if defined $p->{$k};

        if ( defined $p->{$k}
             and ( $is_create
                   or $p->{$k} ne $self->$k() )
             and Socialtext::User->new_homunculus( $k => $p->{$k} ) ) {
            push @errors, loc("The [_1] you provided ([_2]) is already in use.", Socialtext::Data::humanize_column_name($k), $p->{$k});
        }

        if ( ( exists $p->{$k} or $is_create )
             and not
             ( defined $p->{$k} and length $p->{$k} ) ) {
            push @errors, 
                    loc('[_1] is a required field.', ucfirst Socialtext::Data::humanize_column_name($k));

        }
    }

    if ( defined $p->{email_address} && length $p->{email_address}
         && ! Email::Valid->address( $p->{email_address} ) ) {
        push @errors, loc("[_1] is not a valid email address.",$p->{email_address});
    }

    if ( defined $p->{password} && length $p->{password} < 6 ) {
        push @errors, $self->ValidatePassword( password => $p->{password} );
    }

    if ( delete $p->{require_password}
         and $is_create and not defined $p->{password} ) {
        push @errors, loc('A password is required to create a new user.');
    }

    if ( not $is_create and $metadata ) {
        if ( $metadata->is_system_created ) {
            push @errors,
                loc("You cannot change the name of a system-created user.")
                if $p->{username};

            push @errors,
                loc("You cannot change the email address of a system-created user.")
                if $p->{email_address};
        }
    }

    data_validation_error errors => \@errors if @errors;

    if ( $is_create and not ( defined $p->{password} and length $p->{password} ) ) {
        $p->{password} = '*none*';
        $p->{no_crypt} = 1;
    }

    # we don't care about different salt per-user - we crypt to
    # obscure passwords from ST admins, not for real protection (in
    # which case we would not use crypt)
    $p->{password} = $self->_crypt( $p->{password}, 'salty' )
        if exists $p->{password} && ! delete $p->{no_crypt};

    if ( $is_create and $p->{username} ne $SystemUsername ) {
        # this will not exist when we are making the system user!
        $p->{created_by_user_id} ||= Socialtext::User->SystemUser()->user_id;
    }
}

sub _crypt {
    shift;
    my $pw   = shift;
    my $salt = shift;

    $pw = Encode::encode( 'utf8', $pw );
    return crypt( $pw, $salt );
}

sub _clean_username_or_email {
    my $str = shift;
    return Socialtext::String::trim(lc $str);
}

1;

__END__

=head1 NAME

Socialtext::User::Default - A Socialtext RDBMS User Factory

=head1 SYNOPSIS

  use Socialtext::User::Default;

  my $user = Socialtext::User::Default->new( user_id => $user_id );

  my $user = Socialtext::User::Default->new( username => $username );

  my $user = Socialtext::User::Default->new( email_address => $email_address );

=head1 DESCRIPTION

This class provides methods for dealing with data from the User
table. Each object represents a single row from the table.

=head1 METHODS

=head2 Socialtext::User::Default->table_name()

Returns the name of the table where User data lives.

=head2 Socialtext::User::Default->new(PARAMS)

Looks for an existing user matching PARAMS and returns a
C<Socialtext::User::Default> object representing that user if it exists.

PARAMS can be I<one> of:

=over 4

=item * user_id => $user_id

=item * username => $username

=item * email_address => $email_address

=back

=head2 Socialtext::User::Default->create(PARAMS)

Attempts to create a user with the given information and returns a new
C<Socialtext::User::Default> object representing the new user.

PARAMS can include:

=over 4

=item * username - required

=item * email_address - required

=item * password - see below for default

Normally, the value for "password" should be provided in unencrypted
form.  It will be stored in the DBMS in C<crypt()>ed form.  If you
must pass in a crypted password, you can also pass C<< no_crypt => 1
>> to the method.

The password must be at least six characters long.

If no password is specified, the password will be stored as the string
"*none*", unencrypted. This will cause the C<<
$user->has_valid_password() >> method to return false for this user.

=item * require_password - defaults to false

If this is true, then the absence of a "password" parameter is
considered an error.

=item * first_name

=item * last_name

=back

=head2 $user->update(PARAMS)

Updates the user's information with the new key/val pairs passed in.  You
cannot change username or email_address for a row where is_system_created is
true.

=head2 $user->delete()

Deletes the user record from the store.

=head2 $user->user_id()

=head2 $user->username()

=head2 $user->email_address()

=head2 $user->first_name()

=head2 $user->last_name()

=head2 $user->driver_name()

Returns the corresponding attribute for the user.

=head2 $user->delete()

By default, this method simply throws an exception. In almost all
cases, users should not be deleted, as they are foreign keys for too
many other tables, and even if a user is no longer active, they are
still likely to be needed when looking up page authors and other
information.

If you pass C<< force => 1 >> this will force the deletion through.

As an alternative to deletion, you can block a user from logging in by
setting their password to some string and passing C<< no_crypt => 1 >>
to C<update()>

=head2 $user->to_hash()

Returns a hash reference representation of the user, suitable for using with
JSON, YAML, etc.  B<WARNING:> The encryted password is included in this hash,
and should usually be removed before passing the hash over the threshold.

=head2 $user->password_is_correct($pw)

Returns a boolean indicating whether or not the given password is
correct.

=head2 $user->has_valid_password()

Returns true if the user has a valid password.

For now, this is defined as any password not matching "*none*".

=head2 Socialtext::User::Default->ValidatePassword( password => $pw )

Given a password, this returns a list of error messages if the
password is invalid.

=head2 Socialtext::User::Default->EnsureRequiredDataIsPresent()

Inserts required users into the DBMS if they are not present. See
L<Socialtext::Data> for more details on required data.

=head2 Socialtext::User::Default->Count()

Return the number of User records in the database.

=head2 Socialtext::User::Default->Search( 'foo' )

Search for user records where 'foo' is found in any of username, email
address, first name, or last name. Returns a list of hashes containing
three key-value pairs:

=over 4

=item driver_key => Socialtext::User::LDAP->driver_key

=item email_address => the email_address of the record

=item name_and_email => the result of passing in the record's
first_name, last_name, and email_address to
Socialtext::User->name_and_email()

=back

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005 Socialtext, Inc., All Rights Reserved.

=cut
