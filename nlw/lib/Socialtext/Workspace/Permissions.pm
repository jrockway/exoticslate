# @COPYRIGHT@
package Socialtext::Workspace::Permissions;
use strict;
use warnings;
use Readonly;
use Socialtext::SQL qw( sql_execute sql_commit sql_rollback sql_begin_work
                        sql_in_transaction);
use Socialtext::Validate qw(
    validate validate_pos SCALAR_TYPE BOOLEAN_TYPE ARRAYREF_TYPE
    HANDLE_TYPE URI_TYPE USER_TYPE ROLE_TYPE PERMISSION_TYPE FILE_TYPE
    DIR_TYPE UNDEF_TYPE
);
use Socialtext::Permission qw( ST_EMAIL_IN_PERM ST_READ_PERM );
use Socialtext::l10n qw(loc system_locale);
use Socialtext::Exceptions qw( rethrow_exception );

our %PermissionSets = (
    'public' => {
        guest              => [ qw( read edit comment ) ],
        authenticated_user => [ qw( read edit comment email_in ) ],
        member             => [ qw( read edit attachments comment delete
                                    email_in email_out ) ],
        workspace_admin    => [ qw( read edit attachments comment delete
                                    email_in email_out admin_workspace ) ],
    },
    'member-only' => {
        guest              => [ ],
        authenticated_user => [ 'email_in' ],
        member             => [ qw( read edit attachments comment delete
                                    email_in email_out ) ],
        workspace_admin    => [ qw( read edit attachments comment delete
                                    email_in email_out admin_workspace ) ],
    },
    'authenticated-user-only' => {
        guest              => [ ],
        authenticated_user => [ qw( read edit attachments comment delete
                                    email_in email_out ) ],
        member             => [ qw( read edit attachments comment delete
                                    email_in email_out ) ],
        workspace_admin    => [ qw( read edit attachments comment delete
                                    email_in email_out admin_workspace ) ],
    },
    'public-read-only' => {
        guest              => [ 'read' ],
        authenticated_user => [ 'read' ],
        member             => [ qw( read edit attachments comment delete
                                    email_in email_out ) ],
        workspace_admin    => [ qw( read edit attachments comment delete
                                    email_in email_out admin_workspace ) ],
    },
    'public-comment-only' => {
        guest              => [ qw( read comment ) ],
        authenticated_user => [ qw( read comment ) ],
        member             => [ qw( read edit attachments comment delete
                                    email_in email_out ) ],
        workspace_admin    => [ qw( read edit attachments comment delete
                                    email_in email_out admin_workspace ) ],
    },
    'public-authenticate-to-edit' => {
        guest              => [ qw( read edit_controls ) ],
        authenticated_user => [ qw( read edit attachments comment delete
                                    email_in email_out ) ],
        member             => [ qw( read edit attachments comment delete
                                    email_in email_out ) ],
        workspace_admin    => [ qw( read edit attachments comment delete
                                    email_in email_out admin_workspace ) ],
    },
    'intranet' => {
        guest              => [ qw( read edit attachments comment delete
                                    email_in email_out ) ],
        authenticated_user => [ qw( read edit attachments comment delete
                                    email_in email_out ) ],
        member             => [ qw( read edit attachments comment delete
                                    email_in email_out ) ],
        workspace_admin    => [ qw( read edit attachments comment delete
                                    email_in email_out admin_workspace ) ],
    },
);

my @PermissionSetsLocalize = (loc('public'), loc('member-only'), loc('authenticated-user-only'), loc('public-read-only'), loc('public-comment-only'), loc('public-authenticate-to-edit') ,loc('intranet'));

# Impersonators should be able to do everything members can do, plus
# impersonate.
$_->{impersonator} = [ 'impersonate', @{ $_->{member} } ]
    for values %PermissionSets;


sub new {
    my $class = shift;
    my %opts = @_;
    my $self = { %opts };
    bless $self, $class;
    return $self;
}

{
    Readonly my $spec => {
        set_name => {
            callbacks => {
                 'valid permission set name' =>
                 sub { $_[0] && exists $PermissionSets{ $_[0] } },
            },
        },
    };
    sub set {
        my $self = shift;
        my $in_transaction = sql_in_transaction();
        eval {
            sql_begin_work() unless $in_transaction;
            $self->_set_permissions(@_);
            sql_commit unless $in_transaction;
        };
        if ( my $e = $@ ) {
            sql_rollback() unless $in_transaction;
            rethrow_exception($e);
        }
    }

    sub _set_permissions {
        my $self = shift;
        my %p = validate( @_, $spec );
        my $wksp = $self->{wksp};

        my $workspace_id = $wksp->workspace_id;
        my $set = $PermissionSets{ $p{set_name} };

        # We need to preserve the guest's email_in permission
        my $guest_id    = Socialtext::Role->Guest()->role_id();
        my $email_in_id = ST_EMAIL_IN_PERM->permission_id();
        my $sth = sql_execute(<<EOSQL, $workspace_id, $guest_id, $email_in_id);
SELECT role_id, permission_id FROM "WorkspaceRolePermission"
    WHERE workspace_id = ?
      AND role_id = ?
      AND permission_id = ?
EOSQL
        my $perms_to_keep = $sth->fetchall_arrayref->[0];

        # Delete the old permissions, and count how many we deleted
        my $dbh = Socialtext::SQL::get_dbh();
        $sth = $dbh->prepare(<<EOSQL);
DELETE FROM "WorkspaceRolePermission"
    WHERE workspace_id = ?
EOSQL
        my $rv = $sth->execute($workspace_id);
        my $has_existing_perms = $rv ne '0E0';

        # Add the new permissions
        my @new_perms = $perms_to_keep ? ($perms_to_keep) : ();
        for my $role_name ( keys %$set ) {
            my $role = Socialtext::Role->new( name => $role_name );
            for my $perm_name ( @{ $set->{$role_name} } ) {
                next if $role_name eq 'guest' and $perm_name eq 'email_in'
                        and $has_existing_perms;

                my $perm = Socialtext::Permission->new( name => $perm_name );
                push @new_perms, [$role->role_id, $perm->permission_id];
            }
        }

        # Firehose the permissions into the database
        if (@new_perms) {
            $dbh->do('COPY "WorkspaceRolePermission" FROM STDIN');
            for my $p (@new_perms) {
                $dbh->pg_putline("$workspace_id\t$p->[0]\t$p->[1]\n");
            }
            $dbh->pg_endcopy;
        }

        my $html_wafl = ( $p{set_name} =~ /^(member|intranet|public\-read)/ ) ? 1 : 0;
        my $email_addresses = ( $p{set_name} =~ /^(member|intranet)/ ) ? 0 : 1 ;
        my $email_notify = ( $p{set_name} =~ /^public/ ) ? 0 : 1;
        my $homepage = ( $p{set_name} eq 'member-only' ) ? 1 : 0;
        $wksp->update(
            allows_html_wafl           => $html_wafl,
            email_notify_is_enabled    => $email_notify,
            email_addresses_are_hidden => $email_addresses,
            homepage_is_dashboard      => $homepage,
        );
    }
}

{
    # This is just caching to make current_set_name run at a
    # reasonable speed.
    my %SetsAsStrings =
        map { $_ => _perm_set_as_string( $PermissionSets{$_} ) }
        keys %PermissionSets;

    sub current_set {
        my $self = shift;
        my $perms_with_roles = $self->permissions_with_roles();

        my %set;
        while ( my $pair = $perms_with_roles->next ) {
            my ( $perm, $role ) = @$pair;
            push @{ $set{ $role->name() } }, $perm->name();
        }

        # We need the contents of %set to match our pre-defined sets,
        # which assign an empty arrayref for a role when it has no
        # permissions (see authenticated-user-only).
        my $roles = Socialtext::Role->All();
        while ( my $role = $roles->next() ) {
            $set{ $role->name() } ||= [];
        }

        return %set;
    }

    sub current_set_name {
        my $self = shift;

        my %set = $self->current_set;

        my $set_string = _perm_set_as_string( \%set );
        for my $name ( keys %SetsAsStrings ) {
            return $name if $SetsAsStrings{$name} eq $set_string;
        }

        return 'custom';
    }

    sub _perm_set_as_string {
        my $set = shift;

        my @parts;
        # This particular string dumps nicely, the newlines are not
        # special or anything.
        for my $role ( sort keys %{$set} ) {
            my $string = "$role: ";
            # We explicitly ignore the email_in permission as applied
            # to guests when determining the set string so that it
            # does not affect the calculated set name for a
            # workspace. See RT 21831.
            my @perms = sort @{ $set->{$role} };
            @perms = grep { $_ ne 'email_in' } @perms
                if $role eq 'guest';

            $string .= join ', ', @perms;

            push @parts, $string;
        }

        return join "\n", @parts;
    }
}


{
    Readonly my $spec => {
        permission => PERMISSION_TYPE,
        role       => ROLE_TYPE,
    };
    sub add {
        my $self = shift;
        my $wksp = $self->{wksp};
        my %p = validate( @_, $spec );

        eval {
            sql_execute('INSERT INTO "WorkspaceRolePermission" VALUES (?,?,?)',
                $wksp->workspace_id, $p{role}->role_id,
                $p{permission}->permission_id);
        };
        if ($@ and $@ !~ m/duplicate key/) {
            die $@;
        }
    }

    sub remove {
        my $self = shift;
        my $wksp = $self->{wksp};
        my %p = validate( @_, $spec );

        sql_execute(<<EOSQL,
DELETE FROM "WorkspaceRolePermission"
    WHERE workspace_id = ?
      AND role_id = ?
      AND permission_id = ?
EOSQL
            $wksp->workspace_id, $p{role}->role_id,
            $p{permission}->permission_id);
    }

    sub role_can {
        my $self = shift;
        my $wksp = $self->{wksp};
        my %p = validate( @_, $spec );

        my $sth = sql_execute(<<EOSQL,
SELECT * FROM "WorkspaceRolePermission"
    WHERE workspace_id = ?
      AND role_id = ?
      AND permission_id = ?
EOSQL
            $wksp->workspace_id, $p{role}->role_id,
            $p{permission}->permission_id);

        my $perm = $sth->fetchall_arrayref->[0];
        return $perm ? 1 : 0;
    }
}

{
    Readonly my $spec => {
        role => ROLE_TYPE,
    };
    sub permissions_for_role {
        my $self = shift;
        my $wksp = $self->{wksp};

        my %p = validate( @_, $spec );

        my $sth = sql_execute(<<EOSQL, $wksp->workspace_id, $p{role}->role_id );
SELECT permission_id
    FROM "WorkspaceRolePermission"
    WHERE workspace_id=? AND role_id=?
EOSQL

        return Socialtext::MultiCursor->new(
            iterables => [ $sth->fetchall_arrayref ],
            apply     => sub {
                my $row = shift;
                return Socialtext::Permission->new(
                    permission_id => $row->[0] );
            }
        );
    }
}

sub permissions_with_roles {
    my $self = shift;
    my $wksp = $self->{wksp};

    my $sth = sql_execute(<<EOSQL, $wksp->workspace_id);
SELECT permission_id, role_id
    FROM "WorkspaceRolePermission"
    WHERE workspace_id = ?
EOSQL

    return Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref ],
        apply     => sub {
            my $row = shift;
            my $permission_id = $row->[0];
            my $role_id = $row->[1];

            return undef unless defined $permission_id;
            return [
                Socialtext::Permission->new( permission_id => $permission_id ),
                Socialtext::Role->new( role_id             => $role_id )
            ];
        }
    );
}

{
    Readonly my $spec => {
        user       => USER_TYPE,
        permission => PERMISSION_TYPE,
    };
    sub user_can {
        my $self = shift;
        my $wksp_id = $self->{wksp}->workspace_id;
        my %p = validate( @_, $spec );

        my $sth = sql_execute(<<EOSQL,
SELECT * FROM "WorkspaceRolePermission"
    WHERE workspace_id = ?
      AND permission_id = ?
      AND role_id IN (
        SELECT role_id FROM "UserWorkspaceRole"
            WHERE workspace_id = ?
              AND user_id = ?
      )
EOSQL
            $wksp_id,
            $p{permission}->permission_id,
            $wksp_id,
            $p{user}->user_id,
        );
        my $has_permission = $sth->fetchall_arrayref->[0];
        return 1 if $has_permission;

        return 1 if $self->role_can(
            role       => $p{user}->default_role,
            permission => $p{permission},
        );
    }
}

sub is_public {
    my $self = shift;

    return $self->role_can(
        role       => Socialtext::Role->Guest(),
        permission => ST_READ_PERM,
    );
}

sub SetNameIsValid {
    my $class = shift;
    my $name  = shift;

    return $PermissionSets{$name} ? 1 : 0;
}

1;

__END__

=head1 NAME

Socialtext::Workspace::Permissions - An object to query/manipulate workspace permissions.

=head2 $workspace_permissions->set( set_name => $name )

Given a permission-set name, this method sets the workspace's
permissions according to the definition of that set.

The valid set names and the permissions they give are shown below.
Additionally, all permission sets give the same permissions as C<member> plus
C<impersonate> to the C<impersonator> role.

=over 4

=item * public

=over 8

=item o guest - read, edit, comment

=item o authenticated_user - read, edit, comment, email_in

=item o member - read, edit, attachments, comment, delete, email_in, email_out

=item o workspace_admin - read, edit, attachments, comment, delete, email_in, email_out

=back

=item * member-only

=over 8

=item o guest - none

=item o authenticated_user - email_in

=item o member - read, edit, attachments, comment, delete, email_in, email_out

=item o workspace_admin - read, edit, attachments, comment, delete, email_in, email_out

=back

=item * authenticated-user-only

=over 8

=item o guest - none

=item o authenticated_user - read, edit, attachments, comment, delete, email_in, email_out

=item o member - read, edit, attachments, comment, delete, email_in, email_out

=item o workspace_admin - read, edit, attachments, comment, delete, email_in, email_out

=back

=item * public-read-only

=over 8

=item o guest - read

=item o authenticated_user - read

=item o member - read, edit, attachments, comment, delete, email_in, email_out

=item o workspace_admin - read, edit, attachments, comment, delete, email_in, email_out

=back

=item * public-comment-only

=over 8

=item o guest - read, comment

=item o authenticated_user - read, comment

=item o member - read, edit, attachments, comment, delete, email_in, email_out

=item o workspace_admin - read, edit, attachments, comment, delete, email_in, email_out

=back

=item * public-authenticate-to-edit

=over 8

=item o guest - read, edit_controls

=item o authenticated_user - read, edit, attachments, comment, delete, email_in, email_out

=item o member - read, edit, attachments, comment, delete, email_in, email_out

=item o workspace_admin - read, edit, attachments, comment, delete, email_in, email_out

=back

=item * intranet

=over 8

=item o guest - read, edit, attachments, comment, delete, email_in, email_out

=item o authenticated_user - read, edit, attachments, comment, delete, email_in, email_out

=item o member - read, edit, attachments, comment, delete, email_in, email_out

=item o workspace_admin - read, edit, attachments, comment, delete, email_in, email_out

=back

=back

Additionally, when a name that starts with public is given, this
method will also change allows_html_wafl and email_notify_is_enabled
to false.

=head2 $workspace_permissions->role_can( permission => $perm, role => $role );

Returns a boolean indicating whether the specified role has the given
permission.

=head2 $workspace_permissions->current_set()

Returns the workspace's current permission set as a hash.

=head2 $workspace_permissions->current_set_name()

Returns the name of the workspace's current permission set. If it does
not match any of the pre-defined sets this method returns "custom".

=head2 $workspace_permissions->add( permission => $perm, role => $role );

This methods adds the given permission for the specified role.

=head2 $workspace_permissions->remove( permission => $perm, role => $role );

This methods removes the given permission for the specified role.

=head2 $workspace_permissions->permissions_for_role( role => $role );

Returns a cursor of C<Socialtext::Permission> objects indicating what
permissions the specified role has in this workspace.

=head2 $workspace_permissions->permissions_with_roles

Returns a cursor of C<Socialtext::Permission> and C<Socialtext::Role>
objects indicating the permissions for each role in the workspace.

=head2 $workspace_permissions->is_public()

This returns true if guests have the "read" permission for the workspace.

=head2 Socialtext::Workspace::Permissions->SetNameIsValid($name)

Returns a boolean indicating whether or not the given set name is
valid.

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005 Socialtext, Inc., All Rights Reserved.

=cut
