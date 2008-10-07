# @COPYRIGHT@
package Socialtext::UserId;

use strict;
use warnings;

our $VERSION = '0.01';

use Class::Field 'field';
use Socialtext::Cache;
use Socialtext::SQL qw(sql_execute sql_singlevalue);

field 'user_id';
field 'driver_key';
field 'driver_unique_id';
field 'driver_username';

sub create_if_necessary {
    my $class = shift;
    my $homunculus = shift;

    my @primary_params = (
        driver_key       => $homunculus->driver_key,
        driver_unique_id => $homunculus->user_id,
    );

    my @fallback_params = (
        driver_key      => $homunculus->driver_key,
        driver_username => $homunculus->username,
    );

    my $user_id = $class->_new_from_homunculus(@primary_params);

    if (!defined $user_id) {
        $user_id = $class->_new_from_homunculus(@fallback_params);
    }

    if ($user_id) {
        if ($user_id->_homunculus_is_different($homunculus)) {
            $user_id->update(
                driver_unique_id => $homunculus->user_id,
                driver_username  => $homunculus->username
            );
        }
        return $user_id;
    }
    
    my $new_id = $class->NewUserId();
    return $class->create( 
        @primary_params,
        driver_username => $homunculus->username,
        user_id => $new_id
    );
}

sub _homunculus_is_different {
    my $self = shift;
    my $homunculus = shift;
    # if the homunculus is different from our user id, update                                               
    # our database with homunculus data                                                                     
    return ( $self->driver_username ne $homunculus->username ||
             $self->driver_unique_id ne $homunculus->user_id );
}



sub new {
    my ( $class, %p ) = @_;

    return
        exists $p{user_id}
        ? $class->_new_from_user_id(%p)
        : $class->_new_from_homunculus(%p);
}

sub _cache {
    return Socialtext::Cache->cache('user_id');
}

sub _new_from_user_id {
    my ( $class, %p ) = @_;

    # 'user_id' should *only* ever be numeric; if its anything else,
    # fail quietly.
    #
    # Need this check as other User Factories may have non-numeric user
    # ids, and a lookup by "user_id" may get passed through to this
    # factory with a non-numeric value.
    if (exists $p{user_id} && ($p{user_id} =~ /\D/)) {
        return undef;
    }

    # cache-get/instantiate the UserId object
    my $cache = $class->_cache();
    my $key   = "user_id=$p{user_id}";

    my $user_id = $cache->get($key);
    unless ($user_id) {
        $user_id = $class->_new_from_where(
            'user_id=?' => $p{user_id});
        $cache->set($key, $user_id);
    }
    return $user_id;
}

sub _new_from_homunculus {
    my ( $class, %p ) = @_;

    my $where_clause;
    my @args;

    my $key;
    if (exists $p{driver_unique_id}) {
        $key = "$p{driver_key}-id=$p{driver_unique_id}";
        $where_clause = 'driver_key=? AND driver_unique_id=?';
        @args = ($p{driver_key}, $p{driver_unique_id});
    }
    else {
        $key = "$p{driver_key}-user=$p{driver_username}";
        $where_clause = 'driver_key=? AND driver_username=?';
        @args = ($p{driver_key}, $p{driver_username});
    }

    my $cache   = $class->_cache();
    my $user_id = $cache->get($key);
    unless ($user_id) {
        $user_id = $class->_new_from_where(
            $where_clause => @args,
        );
        $cache->set( $key, $user_id );
    }
    return $user_id;
}

sub _new_from_where {
    my ( $class, $where_clause, @bindings ) = @_;

    my $sth = sql_execute(
        'SELECT user_id, driver_key, driver_unique_id, driver_username'
        . ' FROM "UserId"'
        . " WHERE $where_clause",
        @bindings );

    my @rows = @{ $sth->fetchall_arrayref };
    return @rows ? bless {
                    user_id => $rows[0][0],
                    driver_key       => $rows[0][1],
                   driver_unique_id => $rows[0][2],
                    driver_username  => $rows[0][3],
                    }, $class
                 : undef;
}

sub NewUserId {
    my $id = sql_singlevalue(q{SELECT nextval('"UserId___user_id"')});
    return $id;
}

sub create {
    my ( $class, %p ) = @_;

    die "need to supply a user_id; use GetUniqueId"
        unless $p{user_id};

    sql_execute(
        'INSERT INTO "UserId"'
        . ' (user_id, driver_key, driver_unique_id, driver_username)'
        . ' VALUES (?,?,?,?)',
        $p{user_id}, $p{driver_key}, $p{driver_unique_id}, $p{driver_username} );

    return $class->new(%p);
}

sub delete {
    my $self = shift;

    my $sth = sql_execute(
        'DELETE FROM "UserId" WHERE user_id=?',
        $self->user_id
    );

    # flush cache; removed a UserId from the DB
    $self->_cache->clear();

    return $sth;
}

# "update" methods: set_driver_username
sub update {
    my ( $self, %p ) = @_;

    my ( @updates, @bindings );
    while (my ($column, $value) = each %p) {
        push @updates, "$column=?";
        push @bindings, $value;
    }
    my $set_clause = join ', ', @updates;

    sql_execute(
        qq{UPDATE "UserId" SET $set_clause WHERE user_id=?},
        @bindings, $self->user_id
    );

    while (my ($column, $value) = each %p) {
        $self->$column($value);
    }

    # flush cache; updated UserId record
    $self->_cache->clear();

    return $self;
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

=head2 Socialtext::UserId->NewUserId()

Returns a new unique identifier for use in creating new users.

=head2 Socialtext::UserId->create(PARAMS)

Attempts to create a user metadata record with the given information and
returns a new C<Socialtext>::UserId object.  Be sure to call NewUserId to
get a new user_id to pass in.

PARAMS can include:

=over 4

=item * user_id - required

=item * driver_key - required

=item * driver_unique_id - required

=item * driver_username - required

=back

=head2 Socialtext::UserId->create_if_necessary( $user )

Tries to find the appropriate UserId row corresponding to $user, updating the
username column, if found. This keeps the username column up to date.

=head2 $uid->update( driver_username => $new_username )

Updates the UserId record's driver_username field. Since this is stored on the
actual user data record, we opportunistically update it whenever we perform a
lookup on the UserId table. 

=head2 $uid->delete()

Delete the record from the database.

=head2 $uid->user_id()

=head2 $uid->driver_key()

=head2 $uid->driver_unique_id()

=head2 $uid->driver_username()

Returns the corresponding attribute for the sparse user information.

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., All Rights Reserved.

=cut
