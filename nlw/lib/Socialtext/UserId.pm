# @COPYRIGHT@
package Socialtext::UserId;

use strict;
use warnings;

our $VERSION = '0.01';

use Readonly;
use Alzabo::SQLMaker::PostgreSQL qw( LOWER );
use Socialtext::Validate qw( validate SCALAR_TYPE );
use Socialtext::Schema;
use Socialtext::String;
use base 'Socialtext::AlzaboWrapper';

__PACKAGE__->SetAlzaboTable( Socialtext::Schema->Load->table('UserId'));
__PACKAGE__->MakeColumnMethods();

sub create_if_necessary {
    my $class = shift;
    my $user = shift;

    my @primary_params = (
        driver_key       => $user->driver_name,
        driver_unique_id => $user->user_id,
    );

    my @fallback_params = (
        driver_key      => $user->driver_name,
        driver_username => $user->username,
    );

    my $user_id = $class->new( @primary_params );

    if (! defined $user_id) {
        $user_id = $class->new( @fallback_params );
    }

    if ($user_id) {
        $user_id->update(
            driver_unique_id => $user->user_id,
            driver_username  => $user->username
        );
        return $user_id;
    }

    return $class->create( @primary_params );
}

{
    Readonly my $spec => {
        driver_key            => SCALAR_TYPE( optional => 0 ),
        driver_unique_id      => SCALAR_TYPE( optional => 1 ),
        driver_username       => SCALAR_TYPE( optional => 1 ),
    };
    sub _new_row {
        my $class = shift;
        my %p     = validate( @_, $spec );

        my $driver_key = Socialtext::String::trim( $p{driver_key} );

        my $driver_user_key_column =
            $p{driver_unique_id}
          ? $class->table->column('driver_unique_id')
          : $class->table->column('driver_username');

        my $driver_user_key =
          Socialtext::String::trim(
            $p{driver_unique_id} ? $p{driver_unique_id} : $p{driver_username} );

        my $row = $class->table->one_row(
            where => [
                [ $class->table->column('driver_key'), '=', $driver_key ],
                'and',
                [ $driver_user_key_column, '=', $driver_user_key ],
            ],
        );

        return $row;
    }
}

1;

__END__

=head1 NAME

Socialtext::UserId - A storage object for minimally aggregated User information

=head1 SYNOPSIS

  use Socialtext::UserId;

  my $uid = Socialtext::UserId->new(
      driver_key       => 'Default',
      driver_unique_id => 5
  );

  my $uid = Socialtext::UserId->create(
      driver_key       => 'Default',
      driver_unique_id => 5,
      driver_username  => 'maryjane@foo.com'
  );

=head1 DESCRIPTION

This class provides methods for dealing with the aggregation of Users no
matter where they are stored. Each object represents a single row from the
table.

=head1 METHODS

=head2 Socialtext::UserId->new(PARAMS)

Looks for existing sparse user information matching PARAMS and returns a
C<Socialtext::UserId> object if it exists.

PARAMS can include:

=over 4

=item * driver_key - required

=item * driver_unique_id - required

=back

=head2 Socialtext::UserId->create(PARAMS)

Attempts to create a user metadata record with the given information and
returns a new C<Socialtext>::UserId object.

PARAMS can include:

=over 4

=item * driver_key - required

=item * driver_unique_id - required

=item * driver_username - required

=back

=head2 Socialtext::UserId->create_if_necessary( $user )

Tries to find the appropriate UserId row corresponding to $user, updating the
username column, if found. This keeps the username column up to date.

=head2 $uid->system_unique_id()

=head2 $uid->driver_key()

=head2 $uid->driver_unique_id()

=head2 $uid->driver_username()

Returns the corresponding attribute for the sparse user information.

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., All Rights Reserved.

=cut
