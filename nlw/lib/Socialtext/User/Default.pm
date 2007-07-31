# @COPYRIGHT@
package Socialtext::User::Default;

use strict;
use warnings;

our $VERSION = '0.01';

use Socialtext::Exceptions qw( data_validation_error param_error );
use Socialtext::Validate qw( validate SCALAR_TYPE BOOLEAN_TYPE ARRAYREF_TYPE WORKSPACE_TYPE );

use Socialtext::AlzaboWrapper::Cursor::Tuple;
use Socialtext::Schema;

use base qw(Socialtext::AlzaboWrapper);

__PACKAGE__->SetAlzaboTable( Socialtext::Schema->Load->table('User') );
__PACKAGE__->MakeColumnMethods();

use Alzabo::SQLMaker::PostgreSQL qw(COUNT DISTINCT LOWER CURRENT_TIMESTAMP);
use DateTime;
use DateTime::Format::Pg;
use Digest::SHA1 ();
use Email::Valid;
use Socialtext::String;
use Readonly;
use Socialtext::Data;
use Socialtext::Role;
use Socialtext::TT2::Renderer;
use Socialtext::URI;
use Socialtext::User;
use Socialtext::UserId;
use Socialtext::UserMetadata;
use Socialtext::UserWorkspaceRole;
use Socialtext::Workspace;
use Socialtext::l10n qw(loc);

my $SystemUsername = 'system-user';
my $GuestUsername  = 'guest';

sub driver_name {
    return 'Default';
}

sub EnsureRequiredDataIsPresent {
    my $class = shift;

    unless ( $class->new( username => $SystemUsername ) ) {
        my $system_user = $class->create(
            username      => $SystemUsername,
            email_address => 'system-user@socialtext.net',
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
            first_name         => 'System',
            last_name          => 'User',
            created_by_user_id => undef,
            is_system_created  => 1,
        );
    }

    unless ( $class->new( username => $GuestUsername ) ) {
        my $system_user = Socialtext::User->new( username => $SystemUsername );
        my $guest_user = $class->create(
            username      => $GuestUsername,
            email_address => 'guest@socialtext.net',
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
            first_name         => 'Guest',
            last_name          => 'User',
            created_by_user_id => $system_user->user_id,
            is_system_created  => 1,
        );
    }
}

{
    Readonly my $spec => {
        username      => SCALAR_TYPE( optional => 1 ),
        email_address => SCALAR_TYPE( optional => 1 ),
    };
    sub _new_row {
        my $class = shift;
        my %p     = validate( @_, $spec );

        unless ( grep { exists $p{$_} }
                 qw( username email_address )
               ) {
            param_error "One of username or email_address "
                        . "are required when calling Socialtext::User::Default->new";
        }

        my $key = $p{username} ? 'username' : 'email_address';

        return $class->table->one_row(
            where => [
                # Need to use LOWER(...) in order to make Pg use the index
                LOWER( $class->table->column($key) ), '=',
                _clean_username_or_email( $p{$key} )
            ],
        );
    }
}

# REVIEW: cut/paste from Socialtext::Workspace.
# REVIEW: turn a user into a hash suitable for JSON and
# such things.
# REVIEW: An Alzabo thing won't serialize directly, we
# need to make queries or otherwise dig into it, so not sure
# what to put in this hash
# REVIEW: We may want even more info than this.
sub to_hash {
    my $self = shift;
    my $hash = {};
    foreach my $column ($self->columns) {
        my $name = $column->name;
        my $value = $self->$name();
        $hash->{$name} = "$value"; # to_string on some objects
    }
    return $hash;
}

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
             and Socialtext::User->new( $k => $p->{$k} ) ) {
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

sub _clean_username_or_email {
    my $str = shift;
    return Socialtext::String::trim(lc $str);
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

sub _crypt {
    shift;
    my $pw   = shift;
    my $salt = shift;

    $pw = Encode::encode( 'utf8', $pw );
    return crypt( $pw, $salt );
}

sub Search {
    my $class = shift;
    my $search_term = shift;

    my $schema = Socialtext::Schema->Load();
    my $user_table = $schema->table('User');

    my $select = $user_table->select(
        select => [
            map { $user_table->column($_) }
                qw(first_name last_name email_address)
        ],
        where => [
            (
                '(',
                [
                    $user_table->column('username'), 'LIKE',
                    '%' . lc $search_term . '%'
                ],
                'or',
                [
                    $user_table->column('email_address'), 'LIKE',
                    '%' . lc $search_term . '%'
                ],
                'or',
                [
                    $user_table->column('first_name'), 'LIKE',
                    '%' . lc $search_term . '%'
                ],
                'or',
                [
                    $user_table->column('last_name'), 'LIKE',
                    '%' . lc $search_term . '%'
                ],
                ')',
            ),
            'and',

            # REVIEW: Not futureproof, would be better to consult UserMetadata
            [
                $user_table->column('username'), 'NOT IN',
                ( $SystemUsername, $GuestUsername )
            ],
        ],
    );

    return Socialtext::MultiCursor->new(
        iterables => [ $select ],
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
