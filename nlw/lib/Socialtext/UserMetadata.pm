# @COPYRIGHT@
package Socialtext::UserMetadata;

use strict;
use warnings;

our $VERSION = '0.01';

use Class::Field 'field';
use Socialtext::Cache;
use Socialtext::Exceptions qw( data_validation_error param_error );
use Socialtext::SQL 'sql_execute';
use Socialtext::Validate qw( validate SCALAR_TYPE BOOLEAN_TYPE ARRAYREF_TYPE 
                             WORKSPACE_TYPE );
use Socialtext::Account;

use DateTime;
use DateTime::Format::Pg;

field 'user_id';
field 'creation_datetime';
field 'last_login_datetime';
field 'email_address_at_import';
field 'created_by_user_id';
field 'is_business_admin';
field 'is_technical_admin';
field 'is_system_created';

sub create_if_necessary {
    my $class = shift;
    my $user = shift;

    my $md = $class->new( user_id => $user->user_id );

    return $md if $md;

    # If we're here, it's because either:
    #  - we've got authenticated user credentials from outside 
    #    our own system
    #  - we're bootstrapping the system with the system-user

    # REVIEW: 'system-user' should probably be gathered from 
    # Socialtext::User, rather than hard-coded here.
    my $created_by_user_id = $user->username eq 'system-user'
        ? undef
        : Socialtext::User->SystemUser->user_id;

    return $class->create(
        user_id => $user->user_id,
        email_address_at_import => $user->email_address,
        created_by_user_id => $created_by_user_id
        );
}

# turn a user into a hash suitable for JSON and
# such things.  Returns our very object, which 
# should alreaby be loaded with our data
sub to_hash { shift }

sub _cache {
    return Socialtext::Cache->cache('user_metadata');
}

sub new {
    my ( $class, %p ) = @_;

    my $cache = $class->_cache();
    my $key   = $p{user_id};

    my $metadata = $cache->get($key);
    unless ($metadata) {
        my $sth = sql_execute(
            'SELECT * FROM "UserMetadata" WHERE user_id=?',
            $p{user_id},
        );

        $metadata = $sth->fetchrow_hashref;
        return undef unless $metadata;
        bless $metadata, $class;

        $cache->set( $key, $metadata );
    }
    return $metadata;
}

sub create {
    my ( $class, %p ) = @_;

    $class->_validate_and_clean_data(%p);
    $p{primary_account_id} ||= Socialtext::Account->Default->account_id;
    $p{is_business_admin}  ||= 'f';
    $p{is_technical_admin} ||= 'f';
    $p{is_system_created}  ||= 'f';

    sql_execute(
        'INSERT INTO "UserMetadata"'
        . ' (user_id, email_address_at_import,'
        . ' created_by_user_id, is_business_admin,'
        . ' is_technical_admin, is_system_created, primary_account_id)'
        . ' VALUES (?,?,?,?,?,?,?)',
        $p{user_id}, $p{email_address_at_import}, $p{created_by_user_id},
        $p{is_business_admin}, $p{is_technical_admin}, $p{is_system_created},
        $p{primary_account_id},
    );

    return $class->new( user_id => $p{user_id} );
}

# "update" methods: set_technical_admin, set_business_admin
sub set_technical_admin {
    my ( $self, $value ) = @_;

    $self->_update_field('is_technical_admin=?', $value);
    $self->is_technical_admin( $value );
    return $self;
}

sub set_business_admin {
    my ( $self, $value ) = @_;

    $self->_update_field('is_business_admin=?', $value);
    $self->is_business_admin( $value );
    return $self;
}

sub record_login { shift->_update_field('last_login_datetime=CURRENT_TIMESTAMP') }

sub _update_field {
    my $self = shift;
    my $field = shift;
    sql_execute(
        qq{UPDATE "UserMetadata" SET $field WHERE user_id=?},
        @_, $self->user_id );
}

sub creation_datetime_object {
    my $self = shift;

    return DateTime::Format::Pg->parse_timestamptz( $self->creation_datetime );
}

sub last_login_datetime_object {
    my $self = shift;

    return DateTime::Format::Pg->parse_timestamptz( $self->last_login_datetime );
}

sub creator {
    my $self = shift;

    my $created_by_user_id = $self->created_by_user_id;

    if (! defined $created_by_user_id) {
        $created_by_user_id = Socialtext::User->SystemUser->user_id;
    }

    return Socialtext::User->new( user_id => $created_by_user_id );
}

sub primary_account {
    my $self = shift;
    my $new_account = shift;

    if ($new_account) {
        my $account_id = ref($new_account) ? $new_account->account_id : $new_account;
        $self->_update_field('primary_account_id=?', $account_id);
        $self->{primary_account_id} = $account_id;
        Socialtext::Cache->clear('authz_plugin');
    }

    return Socialtext::Account->new(account_id => $self->{primary_account_id})
            || Socialtext::Account->Unknown;
}

sub _validate_and_clean_data {
    my $self = shift;
    my $p = shift;
    my $metadata;

    my $is_create = ref $self ? 0 : 1;

    my @errors;
    if ( not $is_create and $p->{is_system_created} ) {
        push @errors,
            "You cannot change is_system_created for a user after it has been created.";
    }

    data_validation_error errors => \@errors if @errors;
}

1;

__END__

=head1 NAME

Socialtext::UserMetadata - A storage object for user metadata

=head1 SYNOPSIS

  use Socialtext::UserMetadata;

  my $md = Socialtext::UserMetadata->new( user_id => 5 );

  my $md = Socialtext::UserMetadata->create_if_necessary( $user );

  my $md = Socialtext::UserMetadata->create( );

=head1 DESCRIPTION

This class provides methods for dealing with data from the UserMetadata
table. Each object represents a single row from the table.

=head1 METHODS

=head2 Socialtext::UserMetadata->new(PARAMS)

Looks for existing user metadata matching PARAMS and returns a
C<Socialtext::UserMetadata> object representing that metadata if it
exists.

=head2 Socialtext::UserMetadata->create(PARAMS)

Attempts to create a user metadata record with the given information and
returns a new C<Socialtext>::UserMetadata object.

PARAMS can include:

=over 4

=item * user_id - required

=item * email_address_at_import - required

=item * created_by_user_id - defaults to Socialtext::User->SystemUser()->user_id()

=back

=head2 Socialtext::UserMetadata->create_if_necessary( $user )

Attempt to retrieve metadata information for $user, if it exists, otherwise,
use information obtained from $user to satisfy a newly created row, and return
it. This is particularly useful when user information is obtained outside the
RDBMS.

$user is typically an instance of one of the Socialtext::User user factories.

=head2 $md->creation_datetime()

=head2 $md->last_login_datetime()

=head2 $md->created_by_user_id()

=head2 $md->is_business_admin()

=head2 $md->is_technical_admin()

=head2 $md->is_system_created()

Returns the corresponding attribute for the user metadata.

=head2 $md->to_hash()

Returns a hash reference representation of the metadata, suitable for using
with JSON, YAML, etc.  

=head2 $md->set_technical_admin($value)

Updates the is_technical_admin for the metadata to $value (0 or 1).

=head2 $md->set_business_admin($value)

Updates the is_business_admin for the metadata to $value (0 or 1).

=head2 $md->record_login()

Updates the last_login_datetime for the metadata to the current datetime.

=head2 $md->creation_datetime_object()

Returns a new C<DateTime.pm> object for the user's creation datetime.

=head2 $md->last_login_datetime_object()

Returns a new C<DateTime.pm> object for the user's last login
datetime. This may be a C<DateTime::Infinite::Past> object if the user
has never logged in.

=head2 $md->creator()

Returns a C<Socialtext::User> object for the user which created this
user.

=head2 $md->primary_account()

Returns a C<Socialtext::Account> object for the primary account this 
user is assigned to.

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005 Socialtext, Inc., All Rights Reserved.

=cut
