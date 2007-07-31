# @COPYRIGHT@
package Socialtext::Account;

use strict;
use warnings;

our $VERSION = '0.01';

use Socialtext::Exceptions qw( data_validation_error );
use Socialtext::Validate qw( validate SCALAR_TYPE );
use Socialtext::l10n qw(loc);

use Socialtext::Schema;
use base 'Socialtext::AlzaboWrapper';
__PACKAGE__->SetAlzaboTable( Socialtext::Schema->Load->table('Account') );
__PACKAGE__->MakeColumnMethods();

use Alzabo::SQLMaker::PostgreSQL qw(COUNT DISTINCT);
use Socialtext::String;
use Readonly;


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

sub _new_row {
    my $class = shift;
    my %p     = validate( @_, { name => SCALAR_TYPE } );

    return $class->table->one_row(
        where => [ $class->table->column('name'), '=', $p{name } ],
    );
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

sub workspaces {
    my $self = shift;

    return
        Socialtext::Workspace->ByAccountId( account_id => $self->account_id, @_ );
}

sub workspace_count {
    my $self = shift;

    my $ws_table = Socialtext::Schema->Load()->table('Workspace');

    return $ws_table->row_count(
        where => [ $ws_table->column('account_id'), '=', $self->account_id ],
    );
}

sub users {
    my $self = shift;

    return
        Socialtext::User->ByAccountId( account_id => $self->account_id, @_ );
}

sub user_count {
    my $self = shift;

    my $schema = Socialtext::Schema->Load();

    my $ws_table = $schema->table('Workspace');
    my $uwr_table = $schema->table('UserWorkspaceRole');

    return $schema->function(
        select => COUNT( DISTINCT( $uwr_table->column('user_id') ) ),
        join   => [ $schema->table('Workspace'), $uwr_table ],
        where  => [ $ws_table->column('account_id'), '=', $self->account_id ],
    );
}

sub Unknown { shift->new( name => 'Unknown' ) }
sub Socialtext { shift->new( name => 'Socialtext' ) }

{
    Readonly my $spec => {
        limit      => SCALAR_TYPE( default => 0 ),
        offset     => SCALAR_TYPE( default => 0 ),
        order_by   => SCALAR_TYPE(
            regex   => qr/^(?:name|user_count|workspace_count)$/,
            default => 'name',
        ),
        sort_order => SCALAR_TYPE(
            regex   => qr/^(?:ASC|DESC)$/i,
            default => 'ASC',
        ),
    };
    sub All {
        my $class = shift;
        my %p = validate( @_, $spec );

        my %limit;
        if ( $p{limit} ) {
            $limit{limit} = [ @p{ 'limit', 'offset' } ];
        }

        my $schema = Socialtext::Schema->Load();
        my $acc_table = $schema->table('Account');

        my @join;

        my @order_by;
        if ( $p{order_by} eq 'name' ) {
            @order_by = ( $acc_table->column('name'), $p{sort_order} );

            @join = $acc_table;

            return $class->cursor(
                $schema->join(
                    select   => $acc_table,
                    join     => \@join,
                    order_by => \@order_by,
                    %limit,
                )
            );
        }
        elsif ( $p{order_by} eq 'workspace_count' ) {
            return $class->_AllByWorkspaceCount(
                sort_order => $p{sort_order},
                %limit,
            );
        }
        elsif ( $p{order_by} eq 'user_count' ) {
            return $class->_AllByUserCount(
                sort_order => $p{sort_order},
                %limit,
            );
        }
    }
}

sub _AllByWorkspaceCount {
    my $class = shift;
    my %p = @_;

    my $schema = Socialtext::Schema->Load();
    my $ws_table = $schema->table('Workspace');
    my $acc_table = $schema->table('Account');

    my %limit = $p{limit} ? ( limit => $p{limit} ) : ();

    my $count = COUNT( $ws_table->column('workspace_id') );
    my $select = $schema->select(
        select   => [ $acc_table->column('account_id'), $count ],
        join     => [ left_outer_join => $acc_table, $ws_table  ],
        order_by => [ $count, $p{sort_order}, $acc_table->column('name'), 'ASC' ],
        group_by => [ $acc_table->column('account_id'), $acc_table->column('name') ],
        %limit,
    );

    return Socialtext::Account::ByAggregateCursor->new(
        cursor => $select,
    );
}

sub _AllByUserCount {
    my $class = shift;
    my %p = @_;

    my $schema = Socialtext::Schema->Load();
    my $ws_table = $schema->table('Workspace');
    my $uwr_table = $schema->table('UserWorkspaceRole');
    my $acc_table = $schema->table('Account');

    my %limit = $p{limit} ? ( limit => $p{limit} ) : ();

    my $count = COUNT( $uwr_table->column('user_id') );
    my $select = $schema->select(
        select   => [ $acc_table->column('account_id'), $count ],
        join     => [
            [ left_outer_join => $acc_table, $ws_table  ],
            [ left_outer_join => $ws_table, $uwr_table  ],
        ],
        order_by => [ $count, $p{sort_order}, $acc_table->column('name'), 'ASC' ],
        group_by => [ $acc_table->column('account_id'), $acc_table->column('name') ],
        %limit,
    );

    return Socialtext::Account::ByAggregateCursor->new(
        cursor => $select,
    );
}

package Socialtext::Account::ByAggregateCursor;

use base qw(Class::AlzaboWrapper::Cursor);

sub next {
    my $self = shift;

    my @vals = $self->{cursor}->next;

    return unless @vals && defined $vals[0];

    return Socialtext::Account->new( account_id => $vals[0] );
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

=item * is_system_generated

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

=item $account->is_system_generated()

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

=back

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2006 Socialtext, Inc., All Rights Reserved.

=cut
