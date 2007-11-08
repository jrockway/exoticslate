# @COPYRIGHT@
package Socialtext::WorkspaceBreadcrumb;
use strict;
use warnings;

use DateTime::Format::Pg;
use Alzabo::SQLMaker::PostgreSQL qw(CURRENT_TIMESTAMP);

use Socialtext::MultiCursor;
use Socialtext::Schema;
use Socialtext::Workspace;
use base 'Socialtext::AlzaboWrapper';
use Socialtext::SQL qw( sql_execute sql_selectrow );
use Socialtext::Permission qw( ST_EMAIL_IN_PERM ST_READ_PERM );

__PACKAGE__->SetAlzaboTable( Socialtext::Schema->Load()->table('WorkspaceBreadcrumb') );
__PACKAGE__->MakeColumnMethods();

sub parsed_timestamp {
    my $self = shift;
    return DateTime::Format::Pg->parse_timestamptz( $self->timestamp );
}

sub List {
    my ( $class, %args ) = @_;

    # back to the sql
    my $sql = <<END_SQL
select
  wb.workspace_id
from
  "WorkspaceBreadcrumb" wb
where
  wb.user_id = ?
and
  exists (select 1 from "UserWorkspaceRole" uwr where wb.user_id = uwr.user_id and wb.workspace_id = uwr.workspace_id)
or
  exists (select 1 from "WorkspaceRolePermission" wrp where wrp.workspace_id = wb.workspace_id and wrp.role_id = ? and wrp.permission_id = ?)
order by
  wb.timestamp desc
limit $args{limit}
END_SQL
;

    my $sth = sql_execute(
        $sql,
        $args{user_id},
        Socialtext::Role->Guest()->role_id,
        ST_READ_PERM->permission_id,
    );

    my $cursor = Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref ],
        apply => sub { $_[0]->[0] },
    );

    my @workspaces = ();
    while ( my $id = $cursor->next ) {
        push @workspaces, Socialtext::Workspace->new( workspace_id => $id );
    }

    return @workspaces;
}

sub Save {
    my $class = shift;

    my $crumb = $class->new(@_);
    if ($crumb) {
        $crumb->update( timestamp => CURRENT_TIMESTAMP() );
        return $crumb;
    }
    else {
        return $class->create(@_);
    }
}


1;

__END__

=head1 NAME

Socialtext::WorkspaceBreadcrumb - Workspace Breadcrumbs

=head1 SYNOPSIS


    # Save breadcrumb
    Socialtext::WorkspaceBreadcrumb->Save(
        user_id => 1,
        workspace_id => 1
    );

    # Get breadcrumbs
    my @workspaces
        = Socialtext::WorkspaceBreadcrumb->List( user_id => 1, limit => 5 );

=head1 DESCRIPTION

This class provides methods for dealing with data from the
WorkspaceBreadcrumb table.

=head1 CLASS METHODS

=over 4

=item Socialtext::WorkspaceBreadcrumb->Save(PARAMS)

Saves a breadcrumb to the table, and return a breadcrumb
C<Socialtext::WorkspaceBreadcrumb> object representing that row.

PARAMS I<must> be:

=over 8

=item * user_id => $user_id

=item * workspace_id => $workspace_id

=back

=item Socialtext::WorkspaceBreadcrumb->List(PARAMS)

Retrieves the last N workspaces visited by the given user id.  The list is a
list of C<Socialtext::Workspace> objects.

PARAMS can include:

=over 8

=item * user_id - required

=item * limit - defaults to 10

=back

=back

=head1 INSTANCE METHODS

=over 4

=item parsed_timestamp()

Returns a DateTime object representing for the time the breadcrumb was
created.

=item timestamp()

Returns a raw string representing the time the breadcrumb was created.

=item workspace_id()

Returns a workspace id for the visited workspace this breadcrumb represents.

=item user_id()

Returns a user id for the user who visited some workspace this breadcrumb
represents.

=back

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2006 Socialtext, Inc., All Rights Reserved.

=cut
