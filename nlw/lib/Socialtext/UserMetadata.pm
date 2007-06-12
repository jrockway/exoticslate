# @COPYRIGHT@
package Socialtext::UserMetadata;

use strict;
use warnings;

our $VERSION = '0.01';

use Socialtext::Exceptions qw( data_validation_error param_error );
use Socialtext::Validate qw( validate SCALAR_TYPE BOOLEAN_TYPE ARRAYREF_TYPE WORKSPACE_TYPE );

use Socialtext::Schema;
use base 'Socialtext::AlzaboWrapper';
__PACKAGE__->SetAlzaboTable( Socialtext::Schema->Load->table('UserMetadata') );
__PACKAGE__->MakeColumnMethods();

use Alzabo::SQLMaker::PostgreSQL qw(COUNT DISTINCT LOWER CURRENT_TIMESTAMP);
use DateTime;
use DateTime::Format::Pg;
use Digest::SHA1 ();
use Email::Valid;
use Socialtext::String;
use Readonly;
use Socialtext::Data;
use Socialtext::EmailSender;
use Socialtext::Role;
use Socialtext::TT2::Renderer;
use Socialtext::URI;
use Socialtext::UserWorkspaceRole;
use Socialtext::Workspace;

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

sub record_login {
    my $self = shift;

    $self->update( last_login_datetime => CURRENT_TIMESTAMP() );
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

=head2 $md->update(PARAMS)

Updates the user's information with the new key/val pairs passed in,
but you cannot change is_system_created after the initial creation of
a row.

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

=head2 $user->record_login()

Updates the last_login_datetime for the user to the current datetime.

=head2 $md->creation_datetime_object()

Returns a new C<DateTime.pm> object for the user's creation datetime.

=head2 $md->last_login_datetime_object()

Returns a new C<DateTime.pm> object for the user's last login
datetime. This may be a C<DateTime::Infinite::Past> object if the user
has never logged in.

=head2 $md->creator()

Returns a C<Socialtext::User> object for the user which created this
user.

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005 Socialtext, Inc., All Rights Reserved.

=cut
