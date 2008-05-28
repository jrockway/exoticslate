# @COPYRIGHT@
package Socialtext::UserWorkspaceRole;

use strict;
use warnings;

use Class::Field 'field';
use Socialtext::SQL qw( sql_execute sql_convert_to_boolean );
use Socialtext::Exceptions qw( rethrow_exception );
our $VERSION = '0.02';

field 'user_id';
field 'workspace_id';
field 'role_id';
field 'is_selected';

# XXX Still need for fixture set up (until that's alzabno'd as well)
sub table_name { 'UserWorkspaceRole' }

sub new {
    my ( $class, %args ) = @_;

    my $sth;
    my $sql = 'select * from "' . table_name() . '" where';
    my $connector = '';
    my @params = ();
    if ($args{workspace_id}) {
        $sql .= " $connector workspace_id = ?";
        $connector = 'and';
        push @params, $args{workspace_id};
    }
    if ($args{user_id}) {
        $sql .= " $connector user_id = ?";
        $connector = 'and';
        push @params, $args{user_id};
    }
    $sth = sql_execute($sql, @params);

    my $row = $sth->fetchrow_hashref();
    return undef if (!defined($row));

    return $class->_new_from_hash_ref($row);
}

sub _new_from_hash_ref {
    my ( $class, $row ) = @_;
    return $row unless $row;
    return bless $row, $class;
}

sub create {
    my $class = shift;
    my %p = @_;

    my $self;

    my @params = ();
    my $sql = 'insert into "' . table_name() . '" (';
    my $connector = '';
    foreach ('workspace_id', 'user_id', 'role_id', 'is_selected') {
        $sql .= "$connector $_";
        $connector = ', ';
        my $value = $p{$_};
        $value = sql_convert_to_boolean($p{$_}, 't') if ($_ eq 'is_selected');
        push @params, $value;
    }
    $sql .= ') values (';
    $sql .= join(',', map {'?'} @params);
    $sql .= ')';

    sql_execute($sql, @params);

    return $class->_new_from_hash_ref(\%p);
}

sub delete {
    my $self = shift;

    my $sql =
        'delete from "' .
        table_name() .
        '" where workspace_id = ? and user_id = ?';
    sql_execute($sql, $self->workspace_id, $self->user_id);
}

sub update {
    my $self = shift;

    my $sql =
        'update "' .
        table_name() .
        '" set role_id = ?, is_selected = ? where workspace_id = ? and user_id = ?';
    sql_execute($sql, $self->role_id, sql_convert_to_boolean($self->is_selected), $self->workspace_id, $self->user_id);
}

1;

__END__

=head1 NAME

Socialtext::UserWorkspaceRole - A user's role in a specific workspace

=head1 SYNOPSIS

  my $uwr = Socialtext::UserWorkspaceRole->new(
      user_id      => $user_id,
      workspace_id => $workspace_id,
  );

=head1 DESCRIPTION

This class provides methods for dealing with data from the
UserWorkspaceRole table. Each object represents a single row from the
table.

=head1 METHODS

=over 4

=item Socialtext::UserWorkspaceRole->table_name()

Returns the name of the table where UserWorkspaceRole data lives.

=back

=over 4

=item Socialtext::UserWorkspaceRole->_new_from_hash_ref(hash)

Returns a new instantiation of the UWR object. Data members for the object
are initialized from the hash reference passed to the method.

=back

=over 4

=item Socialtext::UserWorkspaceRole->new(PARAMS)

Looks for an existing UserWorkspaceRole matching PARAMS and returns a
C<Socialtext::UserWorkspaceRole> object representing that row if it
exists.

PARAMS I<must> be:

=over 8

=item * user_id => $user_id

=item * workspace_id => $workspace_id

=back

=item Socialtext::UserWorkspaceRole->create(PARAMS)

Attempts to create a role with the given information and returns a new
C<Socialtext::UserWorkspaceRole> object representing the new role.

PARAMS can include:

=over 8

=item * user_id - required

=item * workspace_id - required

=item * role_id - required

=item * is_selected - defaults to 0

=back

=item $uwr->update

Update the DB record with new role and is_selected values.

=over 4

=item $uwr->user_id()

=item $uwr->workspace_id()

=item $uwr->role_id()

=item $uwr->is_selected()

Returns the corresponding attribute for the object.

=back

=item $uwr->delete()

Deletes the object from the DBMS.

=back

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2006 Socialtext, Inc., All Rights Reserved.

=cut
