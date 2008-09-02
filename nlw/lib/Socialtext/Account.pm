# @COPYRIGHT@
package Socialtext::Account;

use strict;
use warnings;

our $VERSION = '0.01';

use Class::Field 'field';
use Readonly;
use Socialtext::Exceptions qw( data_validation_error );
use Socialtext::Schema;
use Socialtext::SQL qw( sql_execute sql_singlevalue);
use Socialtext::String;
use Socialtext::Validate qw( validate SCALAR_TYPE );
use Socialtext::l10n qw(loc);
use Socialtext::SystemSettings qw( get_system_setting );

field 'account_id';
field 'name';
field 'is_system_created';

sub table_name { 'Account' }

Readonly my @RequiredAccounts => qw( Unknown Socialtext );
sub EnsureRequiredDataIsPresent {
    my $class = shift;

    for my $name (@RequiredAccounts) {
        next if $class->new( name => $name );

        $class->create(
            name              => $name,
            is_system_created => 1,
        );
    }
}

sub workspaces {
    my $self = shift;

    return
        Socialtext::Workspace->ByAccountId( account_id => $self->account_id, @_ );
}

sub workspace_count {
    my $self = shift;

    my $sql = 'select count(*) from "Workspace" where account_id = ?';
    my $count = sql_singlevalue($sql, $self->account_id);
    return $count;
}

sub users {
    my $self = shift;

    return
        Socialtext::User->ByAccountId( account_id => $self->account_id, @_ );
}

sub user_count {
    my $self = shift;

    my $sth = sql_execute(<<EOT, $self->account_id, $self->account_id);
SELECT COUNT(DISTINCT(u.system_unique_id))
    FROM "UserId" u 
         JOIN "UserMetadata" um ON (u.system_unique_id = um.user_id)
         LEFT JOIN "UserWorkspaceRole" uwr ON (um.user_id = uwr.user_id)
         LEFT JOIN "Workspace" w ON (uwr.workspace_id = w.workspace_id)
    WHERE 
        um.primary_account_id = ? OR w.account_id = ?
EOT

    return $sth->fetchall_arrayref->[0][0];
}

sub Unknown    { $_[0]->new( name => 'Unknown' ) }
sub Socialtext { $_[0]->new( name => 'Socialtext' ) }

sub Default {
    my $class = shift;
    return get_system_setting('default-account');
}

sub new {
    my ( $class, %p ) = @_;

    return exists $p{name} ? $class->_new_from_name(%p)
                           : $class->_new_from_account_id(%p);
}

sub _new_from_name {
    my ( $class, %p ) = @_;

    return $class->_new_from_where('name=?', $p{name});
}

sub _new_from_account_id {
    my ( $class, %p ) = @_;

    return $class->_new_from_where('account_id=?', $p{account_id});
}

sub _new_from_where {
    my ( $class, $where_clause, @bindings ) = @_;

    my $sth = sql_execute(
        'SELECT name, account_id, is_system_created'
        . ' FROM "Account"'
        . " WHERE $where_clause",
        @bindings );
    my @rows = @{ $sth->fetchall_arrayref };
    return @rows    ?   bless {
                            name              => $rows[0][0],
                            account_id        => $rows[0][1],
                            is_system_created => $rows[0][2],
                        }, $class
                    :   undef;
}

sub create {
    my ( $class, %p ) = @_;

    $class->_validate_and_clean_data(\%p);
    exists $p{is_system_created} ? $class->_create_full(%p)
                                 : $class->_create_from_name(%p);

    return $class->new(%p);
}

sub _create_full {
    my ( $class, %p ) = @_;

    sql_execute(
        'INSERT INTO "Account" (account_id, name, is_system_created)'
        . ' VALUES (nextval(\'"Account___account_id"\'),?,?)',
        $p{name}, $p{is_system_created} );
}

sub _create_from_name {
    my ( $class, %p ) = @_;

    sql_execute(
        'INSERT INTO "Account" (account_id, name)'
        . ' VALUES (nextval(\'"Account___account_id"\'),?)',
        $p{name} );
}

sub delete {
    my ($self) = @_;

    sql_execute( 'DELETE FROM "Account" WHERE account_id=?',
        $self->account_id );
}

# "update" methods: set_account_name
sub update {
    my ( $self, %p ) = @_;

    $self->_validate_and_clean_data(\%p);
    sql_execute( 'UPDATE "Account" SET name=? WHERE account_id=?',
        $p{name}, $self->account_id );

    $self->name($p{name});

    return $self;
}

sub Count {
    my ( $class, %p ) = @_;

    my $sth = sql_execute('SELECT COUNT(*) FROM "Account"');
    return $sth->fetchall_arrayref->[0][0];
}

sub CountByName {
    my ( $class, %p ) = @_;
    die "name is mandatory!" unless $p{name};

    my $where = _where_by_name(\%p);
    my $sth = sql_execute(
        qq{SELECT COUNT(*) FROM "Account" $where},
        $p{name},
    );
    return $sth->fetchall_arrayref->[0][0];
}

{
    Readonly my $spec => {
        limit      => SCALAR_TYPE( default => undef ),
        offset     => SCALAR_TYPE( default => 0 ),
        order_by   => SCALAR_TYPE(
            regex   => qr/^(?:name|user_count|workspace_count)$/,
            default => 'name',
        ),
        sort_order => SCALAR_TYPE(
            regex   => qr/^(?:ASC|DESC)$/i,
            default => 'ASC',
        ),
        # For searching by account name
        name             => SCALAR_TYPE( default => undef ),
        case_insensitive => SCALAR_TYPE( default => undef ),
    };
    sub All {
        my $class = shift;
        my %p = validate( @_, $spec );

        if ( $p{order_by} eq 'name' ) {
            return $class->_All( %p );
        }
        elsif ( $p{order_by} eq 'workspace_count' ) {
            return $class->_AllByWorkspaceCount( %p );
        }
        elsif ( $p{order_by} eq 'user_count' ) {
            return $class->_AllByUserCount( %p );
        }
    }
}

sub _All {
    my ( $self, %p ) = @_;

    my $where = '';
    my @args = ($p{limit}, $p{offset});
    if ($p{name}) {
        $where = _where_by_name(\%p);
        unshift @args, $p{name};
    }

    my $sth = sql_execute(
        'SELECT account_id'
        . ' FROM "Account"'
        . $where
        . " ORDER BY name $p{sort_order}"
        . ' LIMIT ? OFFSET ?' ,
        @args );

    return Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref ],
        apply => sub {
            my $row = shift;
            return Socialtext::Account->new( account_id => $row->[0] );
        }
    );
}

sub _AllByWorkspaceCount {
    my ( $self, %p ) = @_;

    my $where = '';
    my @args = ($p{limit}, $p{offset});
    if ($p{name}) {
        $where = _where_by_name(\%p);
        unshift @args, $p{name};
    }

    my $sth = sql_execute(
        'SELECT "Account".account_id,'
        . ' COUNT("Workspace".workspace_id) AS workspace_count'
        . ' FROM "Account"'
        . ' LEFT OUTER JOIN "Workspace" ON'
        . ' "Account".account_id="Workspace".account_id'
        . $where
        . ' GROUP BY "Account".account_id, "Account".name'
        . " ORDER BY workspace_count $p{sort_order}, \"Account\".name ASC"
        . ' LIMIT ? OFFSET ?' ,
        @args );

    return Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref ],
        apply => sub {
            my $row = shift;
            return Socialtext::Account->new( account_id => $row->[0] );
        }
    );
}

sub _AllByUserCount {
    my ( $self, %p ) = @_;

    my $where = '';
    my @args = ($p{limit}, $p{offset});
    if ($p{name}) {
        $where = _where_by_name(\%p);
        unshift @args, $p{name};
    }

    my $sth = sql_execute(
        'SELECT "Account".account_id AS account_id,'
        . ' COUNT("UserWorkspaceRole".user_id) AS user_count'
        . ' FROM "Account"'
        . ' LEFT OUTER JOIN "Workspace" ON'
        . ' "Account".account_id="Workspace".account_id'
        . ' LEFT OUTER JOIN "UserWorkspaceRole" ON'
        . ' "Workspace".workspace_id="UserWorkspaceRole".workspace_id'
        . $where
        . ' GROUP BY "Account".account_id, "Account".name'
        . " ORDER BY user_count $p{sort_order}, \"Account\".name ASC"
        . ' LIMIT ? OFFSET ?',
        @args );

    return Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref ],
        apply => sub {
            my $row = shift;
            return Socialtext::Account->new( account_id => $row->[0] );
        }
    );
}

sub ByName {
    my $class = shift;
    return Socialtext::Account->All( @_ );
}

sub _where_by_name {
    my $p = shift;
    return '' unless $p->{name};

    # Turn our substring into a SQL pattern.
    $p->{name} =~ s/^\s+//; $p->{name} =~ s/\s+$//;
    $p->{name} = "\%$p->{name}\%";

    my $comparator = $p->{case_insensitive} ? 'ILIKE' : 'LIKE';
    return qq{ WHERE "Account".name $comparator ?};
}


sub _validate_and_clean_data {
    my $self = shift;
    my $p = shift;

    my $is_create = ref $self ? 0 : 1;

    $p->{name} = Socialtext::String::trim( $p->{name} );

    my @errors;
    if ( ( exists $p->{name} or $is_create )
         and not
         ( defined $p->{name} and length $p->{name} ) ) {
        push @errors, loc('Account name is a required field.');
    }

    if ( defined $p->{name} && Socialtext::Account->new( name => $p->{name} ) ) {
        push @errors, loc('The account name you chose, [_1], is already in use.',$p->{name} );
    }

    if ( not $is_create and $self->is_system_created and $p->{name} ) {
        push @errors, loc('You cannot change the name of a system-created account.');
    }

    if ( not $is_create and $p->{is_system_created} ) {
        push @errors, loc('You cannot change is_system_created for an account after it has been created.');
    }

    data_validation_error errors => \@errors if @errors;
}

1;

__END__

=head1 NAME

Socialtext::Account - A Socialtext account object

=head1 SYNOPSIS

  use Socialtext::Account;

  my $account = Socialtext::Account->new( account_id => $account_id );

  my $account = Socialtext::Account->new( name => $name );

=head1 DESCRIPTION

This class provides methods for dealing with data from the Account
table. Each object represents a single row from the table.

=head1 METHODS

=over 4

=item Socialtext::Account->table_name()

Returns the name of the table where Account data lives.

=back

=over 4

=item Socialtext::Account->new(PARAMS)

Looks for an existing account matching PARAMS and returns a
C<Socialtext::Account> object representing that account if it exists.

PARAMS can be I<one> of:

=over 8

=item * account_id => $account_id

=item * name => $name

=back

=item Socialtext::->create(PARAMS)

Attempts to create a account with the given information and returns a
new C<Socialtext::Account> object representing the new account.

PARAMS can include:

=over 8

=item * name - required

=item * is_system_created

=back

=item $account->update(PARAMS)

Updates the object's information with the new key/val pairs passed in.
This method accepts the same PARAMS as C<new()>, but you cannot change
"is_system_created" after the initial creation of a row.

=item $account->delete()

Deletes the account from the DBMS, but this is probably a bad idea if
it has any workspaces.

=item $account->account_id()

=item $account->name()

=item $account->is_system_created()

Returns the given attribute for the account.

=item $account->workspace_count()

Returns a count of workspaces for this account.

=item $account->workspaces()

Returns a cursor of the workspaces for this account, ordered by
workspace name.

=item $account->user_count()

Returns a count of users for this account.

=item $account->users()

Returns a cursor of the users for this account, ordered by username.

=item Socialtext::Account->Unknown()

=item Socialtext::Account->Socialtext()

=item Socialtext::Account->Default()

Returns an account object for specified account.

=item Socialtext::Account->All()

Returns a cursor for all the accounts in the system. It accepts the
following parameters:

=over 8

=item * limit and offset

These parameters can be used to add a C<LIMIT> clause to the query.

=item * order_by - defaults to "name"

This must be one "name", "user_count", or "workspace_count".

=item * sort_order - "ASC" or "DESC"

This defaults to "ASC".

=back

=item Socialtext::Account->Count()

Returns a count of all accounts.

=item Socialtext::Account->EnsureRequiredDataIsPresent()

Inserts required accounts into the DBMS if they are not present. See
L<Socialtext::Data> for more details on required data.

=item Socialtext::Account::ByName()

Search accounts by name.  Returns a cursor for the matching counts.

=item Socialtext::Account::CountByName()

Returs a count of accounts matched by name.

=back

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2006 Socialtext, Inc., All Rights Reserved.

=cut
