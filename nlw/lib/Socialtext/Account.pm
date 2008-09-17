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
use YAML qw/DumpFile LoadFile/;

field 'account_id';
field 'name';
field 'skin_name';
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

sub Resolve {
    my $class = shift;
    my $maybe_account = shift;
    my $account;

    if ( $maybe_account =~ /^\d+$/ ) {
        $account = Socialtext::Account->new( account_id => $maybe_account );
    }

    $account ||= Socialtext::Account->new( name => $maybe_account );
    return $account;
}

sub skin_name {
    my ($self, $skin) = @_;

    if (defined $skin) {
        $self->{skin_name} = $skin;
    }
    return $self->{skin_name} || get_system_setting('default-skin');
}

sub reset_skin {
    my ($self, $skin) = @_;
    
    $self->update(skin_name => $skin);
    my $workspaces = $self->workspaces;

    while (my $workspace = $workspaces->next) {
        $workspace->update(skin_name => '');
    }
    return $self->{skin_name};
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

sub is_plugin_enabled {
    my ($self, $plugin) = @_;
    my $sql = q{
        SELECT COUNT(*) FROM account_plugin
        WHERE account_id = ? AND plugin = ?
    };
    return sql_singlevalue($sql, $self->account_id, $plugin);
}

sub enable_plugin {
    my ($self, $plugin) = @_;

    if (!$self->is_plugin_enabled($plugin)) {
        sql_execute(q{
            INSERT INTO account_plugin VALUES (?,?)
        }, $self->account_id, $plugin);
    }
}

sub disable_plugin {
    my ($self, $plugin) = @_;
    sql_execute(q{
        DELETE FROM account_plugin
        WHERE account_id = ? AND plugin = ?
    }, $self->account_id, $plugin);
}

sub export {
    my $self = shift;
    my %opts = @_;
    my $dir = $opts{dir};

    my $export_file = "$dir/account.yaml";
    DumpFile($export_file, {
            name => $self->name,
            is_system_created => $self->is_system_created,
            skin_name => $self->skin_name,
            users => $self->users_as_hash,
        }
    );
    return $export_file;
}

sub users_as_hash {
    my $self = shift;
    my $user_iter = $self->users( primary_only => 1 );
    my @users;
    while ( my $u = $user_iter->next ) {
        my $user_hash = $u->to_hash;
        delete $user_hash->{user_id};
        delete $user_hash->{primary_account_id};
        $user_hash->{profile} = $self->_dump_profile($u);
        push @users, $user_hash;
    }
    return \@users;
}

sub _dump_profile {
    my $self = shift;
    my $user = shift;

    eval "require Socialtext::People::Profile";
    return {} if $@;

    my $profile = Socialtext::People::Profile->GetProfile($user);
    return $profile->to_hash;
}

sub import_file {
    my $class = shift;
    my %opts = @_;
    my $import_file = $opts{file};
    my $import_name = $opts{name};

    my $hash = LoadFile($import_file);
    my $name = $import_name || $hash->{name};
    my $account = $class->new(name => $name);
    if ($account) {
        die loc("Account [_1] already exists!", $name) . "\n" 
            unless $opts{force};
        $account->delete;
    }

    $account = $class->create(
        name => $name,
        is_system_created => $hash->{is_system_created},
        skin_name => $hash->{skin_name},
    );
    
    my @profiles;
    for my $user_hash (@{ $hash->{users} }) {
        my $user = Socialtext::User->new( username => $user_hash->{username} );
        $user ||= Socialtext::User->Create_user_from_hash( $user_hash );
        $user->primary_account($account);

        if (my $profile = delete $user_hash->{profile}) {
            $profile->{user} = $user;
            push @profiles, $profile;
        }
    }

    # Create all the profiles after so that user references resolve.
    eval "require Socialtext::People::Profile";
    unless ($@) {
        print loc("Importing people profiles ...") . "\n";
        Socialtext::People::Profile->create_from_hash( $_ ) for @profiles;
    }

    return $account;
}

sub users {
    my $self = shift;

    return
        Socialtext::User->ByAccountId( account_id => $self->account_id, @_ );
}

sub user_count {
    my $self = shift;
    my $primary_only = shift;

    my $where = '';
    my @bind = ($self->account_id);
    unless ($primary_only) {
        $where = 'OR secondary_account_id = ?';
        push @bind, $self->account_id;
    }
    my $sth = sql_execute(<<EOT, @bind);
SELECT COUNT(DISTINCT(system_unique_id))
    FROM user_account
    WHERE primary_account_id = ? $where
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
        'SELECT name, account_id, is_system_created, skin_name'
        . ' FROM "Account"'
        . " WHERE $where_clause",
        @bindings );
    my @rows = @{ $sth->fetchall_arrayref };
    return @rows    ?   bless {
                            name              => $rows[0][0],
                            account_id        => $rows[0][1],
                            is_system_created => $rows[0][2],
                            skin_name         => $rows[0][3],
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

    my $fields = 'account_id, name, is_system_created';
    my $values = '?,?';
    my @bind = ($p{name}, $p{is_system_created});
    if ($p{skin_name}) {
        $fields .= ', skin_name';
        $values .= ',?';
        push @bind, $p{skin_name};
    }
    sql_execute(
        qq{INSERT INTO "Account" ($fields)}
        . qq{ VALUES (nextval(\'"Account___account_id"\'),$values)},
        @bind,
    );
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

sub update {
    my ( $self, %p ) = @_;

    $self->_validate_and_clean_data(\%p);

    my ( @updates, @bindings );
    while (my ($column, $value) = each %p) {
        push @updates, "$column=?";
        push @bindings, $value;
    }

    if (@updates) {
        my $set_clause = join ', ', @updates;
        sql_execute(
            'UPDATE "Account"'
            . " SET $set_clause WHERE account_id=?",
            @bindings, $self->account_id);

        while (my ($column, $value) = each %p) {
            $self->$column($value);
            $self->{$column} = $value;
        }
    }

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

    $p->{name} = Socialtext::String::trim( $p->{name} )
        if $p->{name};

    my @errors;
    if ( ( exists $p->{name} or $is_create )
         and not
         ( defined $p->{name} and length $p->{name} ) ) {
        push @errors, loc('Account name is a required field.');
    }

    if ( $p->{skin_name} && ! Socialtext::Skin->new(name => $p->{skin_name})) {
        push @errors, loc(
            "The skin you specified, [_1], does not exist.", $p->{skin_name}
        );
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

=item Socialtext::Account->create(PARAMS)

Attempts to create a account with the given information and returns a
new C<Socialtext::Account> object representing the new account.

PARAMS can include:

=over 8

=item * name - required

=item * is_system_created

=back

=item Socialtext::Account->Resolve( $id_or_name )

Looks up the account either by the account id or the name.

=item $account->update(PARAMS)

Updates the object's information with the new key/val pairs passed in.
This method accepts the same PARAMS as C<new()>, but you cannot change
"is_system_created" after the initial creation of a row.

=item $account->delete()

Deletes the account from the DBMS, but this is probably a bad idea if
it has any workspaces.

=item $account->account_id()

=item $account->name()

=item $account->skin_name()

=item $account->is_system_created()

Returns the given attribute for the account.

=item $account->workspace_count()

Returns a count of workspaces for this account.

=item $account->reset_skin($skin)

Change the skin for the account and its workspaces.

=item $account->workspaces()

Returns a cursor of the workspaces for this account, ordered by
workspace name.

=item $account->user_count([ $primary_only ])

Returns a count of users for this account.  If the first parameter is TRUE,
then only users for which this is their primary account will be included.

=item $account->users()

Returns a cursor of the users for this account, ordered by username.

=item $account->is_plugin_enabled($plugin)

Returns true if the specified plugin is enabled for this account.  

Note that the plugin still may be disabled for particular users; use C<Socialtext::User>'s can_use_plugin method to check for this.

=item $account->enable_plugin($plugin)

Enables the plugin for the specified account.

=item $account->disable_plugin($plugin)

Disables the plugin for the specified account.

=item $account->export(dir => $dir)

Export the account data to a file in the specified directory.

=item $account->import_file(file => $file, [ name => $name ])

Imports an account from data in the specified file.  If a name
is supplied, that name will be used instead of the original account name.

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
