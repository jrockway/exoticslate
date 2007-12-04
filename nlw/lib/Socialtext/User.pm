# @COPYRIGHT@
package Socialtext::User;
use strict;
use warnings;

our $VERSION = '0.01';

use Socialtext::Exceptions qw( data_validation_error param_error );
use Socialtext::Validate qw( validate SCALAR_TYPE BOOLEAN_TYPE ARRAYREF_TYPE WORKSPACE_TYPE );
use Socialtext::AppConfig;
use Socialtext::MultiCursor;
use Socialtext::Schema;
use Socialtext::TT2::Renderer;
use Socialtext::URI;
use Socialtext::UserMetadata;
use Socialtext::UserId;
use Socialtext::User::Deleted;
use Socialtext::Workspace;
use Email::Address;
use Class::AlzaboWrapper;
use Class::Field 'field';
use Alzabo::SQLMaker::PostgreSQL qw(COUNT DISTINCT LOWER CURRENT_TIMESTAMP);
use Socialtext::l10n qw(system_locale loc);
use Socialtext::EmailSender::Factory;
use base qw( Socialtext::MultiPlugin );

use Readonly;

field 'homunculus';
field 'metadata';

my @user_store_interface =
    qw( username email_address password first_name last_name );
my @user_metadata_interface =
    qw( creation_datetime last_login_datetime email_address_at_import
        created_by_user_id is_business_admin is_technical_admin
        is_system_created );
my @minimal_interface
    = ( 'user_id', @user_store_interface, @user_metadata_interface );
my $SystemUsername = 'system-user';
my $GuestUsername  = 'guest';

sub minimal_interface {
    my $class = shift;
    return @minimal_interface;
}

sub base_package {
    return __PACKAGE__;
}

sub _drivers {
    my $class = shift;
    my $drivers = Socialtext::AppConfig->user_factories();
    return split /:/, $drivers;
}

sub new_homunculus {
    my $class = shift;
    my $homunculus;

    # if we pass in user_id, it will be one of the new system-wide
    # ids, we must short-circuit and immediately go to the driver
    # associated with that system id

    # if we are passed in an email confirmation hash, we just need the
    # user_id associated with that row in UserEmailConfirmation, and
    # return new_homunculus( user_id => $that_id )

    if ($_[0] eq 'email_confirmation_hash') {
        my $schema = Socialtext::Schema->Load();
        my $uce_table = $schema->table('UserEmailConfirmation');
        my $select = $schema->one_row(
            select => $uce_table,
            join   => $uce_table,
            where  => [ $uce_table->column('sha1_hash'), '=', $_[1] ],
        );

        return undef unless $select;
        return $class->new_homunculus( user_id => $select->select('user_id') );
    }

    if ($_[0] eq 'user_id') {
        my $system_id = Socialtext::UserId->new( system_unique_id => $_[1] );
        my $driver_key = $system_id->driver_key;
        my $driver_unique_id = $system_id->driver_unique_id;
        my $driver_username = $system_id->driver_username;
        my $driver = $class->_realize($driver_key, 'new');
        $homunculus = $driver->new( username => $driver_username );
        $homunculus ||= Socialtext::User::Deleted->new(
            user_id    => $driver_unique_id,
            username   => $system_id->driver_username,
            driver_key => $driver_key,
        );
    }
    else {
        $homunculus = $class->_first('new', @_);
    }

    return $homunculus;
}

sub new {
    my $class = shift;
    my $user = bless {}, $class;

    my $homunculus = $class->new_homunculus(@_);

    if ($homunculus) {
        # ensure this user is present in our UserId table
        Socialtext::UserId->create_if_necessary( $homunculus );

        # fetch the UserMetadata for this user
        $user->homunculus( $homunculus );
        $user->metadata(
            Socialtext::UserMetadata->create_if_necessary( $user ) );

        return $user;
    }

    return undef;
}

sub create {
    my $class = shift;

    # username email_address password first_name last_name
    my %p = @_;
    my %user_p = map { $_ => $p{$_} } @user_store_interface;
    my $homunculus = $class->_first( 'create', %p ); #%user_p );

    my $system_unique_id = Socialtext::UserId->create(
        driver_key       => $homunculus->driver_name,
        driver_unique_id => $homunculus->user_id,
        driver_username  => $homunculus->username,
    )->system_unique_id();

    if ( !exists $p{created_by_user_id} ) {
        if ( $homunculus->username ne $SystemUsername ) {
            my $s_u_homunculus = $class->new_homunculus( username => $SystemUsername );
            my $driver_key = $s_u_homunculus->driver_name;
            my $driver_unique_id = $s_u_homunculus->user_id;
            $p{created_by_user_id} = Socialtext::UserId->new(
                driver_key       => $driver_key,
                driver_unique_id => $driver_unique_id
            )->system_unique_id;
        }
    }
    my $user = bless {}, $class;
    $user->homunculus( $homunculus );
    # scribble UserMetadata
    my %metadata_p = map { $_ => $p{$_} } keys %p; #@user_metadata_interface;;
    $metadata_p{user_id}                 = $system_unique_id;
    $metadata_p{email_address_at_import} = $user->email_address;
    my $metadata = Socialtext::UserMetadata->create(%metadata_p);
    $user->metadata( $metadata );

    return $user;
}

sub SystemUser {
    return shift->new( username => $SystemUsername );
}

sub Guest {
    return shift->new( username => $GuestUsername );
}

sub can_update_store {
    my $self = shift;
    my $homunculus_class = $self->base_package() . "::" . $self->driver_name;
    return $homunculus_class->can('update');
}

sub update_store {
    my $self = shift;
    my %p = @_;
    return $self->homunculus->update( %p );
}

sub user_id {
    my $self = shift;

    return Socialtext::UserId->new(
        driver_key       => $self->homunculus->driver_name,
        driver_unique_id => $self->homunculus->user_id
        )->system_unique_id();
}

sub username {
    $_[0]->homunculus->username( @_[ 1 .. $#_ ] );
}

sub password {
    $_[0]->homunculus->password( @_[ 1 .. $#_ ] );
}

sub email_address {
    $_[0]->homunculus->email_address( @_[ 1 .. $#_ ] );
}

sub first_name {
    my $firstname = $_[0]->homunculus->first_name( @_[ 1 .. $#_ ] );
    Encode::_utf8_on($firstname) unless Encode::is_utf8($firstname);
    return $firstname;
}

sub last_name {
    my $lastname = $_[0]->homunculus->last_name( @_[ 1 .. $#_ ] );
    Encode::_utf8_on($lastname) unless Encode::is_utf8($lastname);
    return $lastname;
}

sub password_is_correct {
    $_[0]->homunculus->password_is_correct( @_[ 1 .. $#_ ] );
}

sub has_valid_password {
    $_[0]->homunculus->has_valid_password( @_[ 1 .. $#_ ] );
}

sub driver_name {
    $_[0]->homunculus->driver_name( @_[ 1 .. $#_ ] );
}

# Metadata delegates

sub email_address_at_import {
    $_[0]->metadata->email_address_at_import( @_[ 1 .. $#_ ] );
}

sub creation_datetime {
    $_[0]->metadata->creation_datetime( @_[ 1 .. $#_ ] );
}

sub last_login_datetime {
    $_[0]->metadata->last_login_datetime( @_[ 1 .. $#_ ] );
}

sub created_by_user_id {
    $_[0]->metadata->created_by_user_id( @_[ 1 .. $#_ ] );
}

sub is_business_admin {
    $_[0]->metadata->is_business_admin( @_[ 1 .. $#_ ] );
}

sub is_technical_admin {
    $_[0]->metadata->is_technical_admin( @_[ 1 .. $#_ ] );
}

sub is_system_created {
    $_[0]->metadata->is_system_created( @_[ 1 .. $#_ ] );
}

sub set_technical_admin {
    $_[0]->metadata->set_technical_admin( @_[ 1 .. $#_ ] );
}

sub set_business_admin {
    $_[0]->metadata->set_business_admin( @_[ 1 .. $#_ ] );
}

sub record_login {
    $_[0]->metadata->record_login( @_[ 1 .. $#_ ] );
}

sub creation_datetime_object {
    $_[0]->metadata->creation_datetime_object( @_[ 1 .. $#_ ] );
}

sub last_login_datetime_object {
    $_[0]->metadata->last_login_datetime_object( @_[ 1 .. $#_ ] );
}

sub creator {
    $_[0]->metadata->creator( @_[ 1 .. $#_ ] );
}

{
    # REVIEW - maybe this is overkill and can be handled through good
    # documentation saying "you probably don't want to delete users,
    # we mean it."
    Readonly my $spec => { force => BOOLEAN_TYPE( default => 0 ) };
    sub delete {
        my $self = shift;
        my %p = validate( @_, $spec );

        Socialtext::Exception->throw( error => 'You cannot delete a user.' )
            unless $p{force};

        # We have three things to delete: Our store, our metadata, and our id
        # user stores should implement a delete method, even if it is a noop.
        Socialtext::UserId->new( system_unique_id => $self->user_id )
            ->delete();
        $self->homunculus->delete();
        $self->metadata->delete();
    }
}

sub to_hash {
  my $self = shift;
  my $hash = {};
  foreach my $attr ( @minimal_interface ) {
      my $value = $self->$attr;
      $value = "" unless defined $value;
      $hash->{$attr} = "$value";
  }

  return $hash;
}

sub _get_full_name {
    my $full_name;
    my $first_name = shift;
    my $last_name = shift;

    if (system_locale() eq 'ja') {
        $full_name = join ' ', grep { defined and length }
            $last_name, $first_name;
    }
    else {
        $full_name = join ' ', grep { defined and length }
        $first_name, $last_name;
    }
    return $full_name;
}


{
    Readonly my $spec => { workspace => WORKSPACE_TYPE( default => undef ) };
    sub best_full_name {
        my $self = shift;
        my %p = validate( @_, $spec );

        my $name = _get_full_name($self->first_name, $self->last_name);

        return $name if length $name;

        return $self->email_address unless $p{workspace};

        return $self->_masked_email_address( $p{workspace} );
    }
}

# REVIEW - in the old code, this always returned the unmasked address
# if the viewing user was a workspace admin
sub _masked_email_address {
    my $self = shift;
    my $workspace = shift;

    my $email = $self->email_address;

    return $email unless $workspace->email_addresses_are_hidden;

    my $unmasked_domain = $workspace->unmasked_email_domain;
    unless ( $unmasked_domain &&
             $email =~ /\@\Q$unmasked_domain\E/ ) {
        $email =~ s/\@.+$/\@hidden/;
    }

    return $email;
}

sub name_and_email {
    my $self = shift;

    return __PACKAGE__->FormattedEmail( $self->first_name, $self->last_name,
        $self->email_address );
}

sub FormattedEmail {
    my ( $class, $first_name, $last_name, $email_address ) = @_;

    my $name = _get_full_name($first_name, $last_name);

    # Dave suggested this improvement, but many of our templates anticipate
    # the previous format, so is being temporarily reverted
    # return Email::Address->new($name, $email_address)->format;

    if ( length $name ) {
            return $name . ' <' . $email_address . '>';
    }
    else {
            return $email_address;
    }
}

sub guess_real_name {
    my $self = shift;

    my $name = _get_full_name($self->first_name, $self->last_name);

    return $name if length $name;

    $name = $self->email_address;
    $name =~ s/\@.+$//;
    $name =~ s/[\.-_]/ /g;

    return $name;
}

sub workspace_count {
    my $self = shift;

    my $uwr_table = Socialtext::Schema->Load()->table('UserWorkspaceRole');

    return $uwr_table->function(
        select => COUNT( DISTINCT( $uwr_table->column('workspace_id') ) ),
        where  => [ $uwr_table->column('user_id'), '=',
                    $self->user_id ],
    );
}

sub workspaces_with_selected {
    my $self = shift;

    my $schema = Socialtext::Schema->Load();
    my $ws_table = $schema->table('Workspace');
    my $uwr_table = $schema->table('UserWorkspaceRole');

    return
        Class::AlzaboWrapper->NewCursor(
            $schema->join(
                join     => [ $ws_table, $uwr_table ],
                where    => [ $uwr_table->column('user_id'),
                              '=', $self->user_id ],
                order_by => $ws_table->column('name'),
            )
        );
}

{
    Readonly my $spec => { workspace => WORKSPACE_TYPE };
    sub workspace_is_selected {
        my $self = shift;
        my %p = validate( @_, $spec );

        my $uwr_table = Socialtext::Schema->Load()->table('UserWorkspaceRole');
        return $uwr_table->function(
            select => $uwr_table->column('is_selected'),
            where  => [
                [ $uwr_table->column('user_id'), '=',
                  $self->user_id ],
                [ $uwr_table->column('workspace_id'), '=',
                  $p{workspace}->workspace_id() ],
            ],
        );
    }
}

{
    Readonly my $spec => { workspaces => ARRAYREF_TYPE };
    sub set_selected_workspaces {
        my $self = shift;
        my %p = validate( @_, $spec );

        my $uwr_table = Socialtext::Schema->Load()->table('UserWorkspaceRole');
        my $uwr_rows = $uwr_table->rows_where(
            where => [ $uwr_table->column('user_id'), '=',
                       $self->user_id ]
        );

        my %selected = map { $_->workspace_id => 1 } @{ $p{workspaces} };
        while ( my $uwr = $uwr_rows->next ) {
            $uwr->update(
                is_selected => $selected{ $uwr->select('workspace_id') }
                ? 1
                : 0 );
        }
    }
}

{
    Readonly my $spec => {
        selected_only => BOOLEAN_TYPE( default => 0 ),
        exclude       => ARRAYREF_TYPE( default => [] ),
        only          => ARRAYREF_TYPE( default => [] ),
    };
    sub workspaces {
        my $self = shift;
        my %p = validate( @_, $spec );

        my $schema = Socialtext::Schema->Load();
        my $ws_table = $schema->table('Workspace');
        my $uwr_table = $schema->table('UserWorkspaceRole');

        my @where = [ $uwr_table->column('user_id'), '=',
                      $self->user_id ];
        push @where, [ $uwr_table->column('is_selected'), '=', 1 ]
            if $p{selected_only};
        push @where, [ $uwr_table->column('workspace_id'), 'NOT IN',
                       @{ $p{exclude} } ]
            if @{ $p{exclude} };

        push @where, [ $ws_table->column('name'), 'IN', @{ $p{only} } ]
            if @{ $p{only} };

        return
            Class::AlzaboWrapper->NewCursor(
                $schema->join(
                    distinct => $ws_table,
                    join     => [ $ws_table, $uwr_table ],
                    where    => \@where,
                    order_by => $ws_table->column('name'),
                )
            );
    }
}

sub is_authenticated {
    my $self = shift;

    return 1
        if $self->username() ne $GuestUsername
           and $self->has_valid_password()
            and not $self->requires_confirmation();

    return 0;
}

sub is_guest {
    return not $_[0]->is_authenticated()
}

sub is_deleted {
    return ref $_[0]->homunculus eq 'Socialtext::User::Deleted';
}

sub default_role {
    my $self = shift;

    return Socialtext::Role->AuthenticatedUser()
        if $self->is_authenticated();

    return Socialtext::Role->Guest();
}

# Class methods

{
    Readonly my $spec => { password => SCALAR_TYPE };
    sub ValidatePassword {
        shift;
        my %p = validate( @_, $spec );

        return ( "Passwords must be at least 6 characters long." )
            unless length $p{password} >= 6;

        return;
    }
}

# helper apply functions
# by workspace count apply
my $by_workspace_count_apply = sub {
    my $rows             = shift;
    my $system_unique_id = $rows->[0];

    # short circuit to not hand back undefs in a list context
    return ( defined $system_unique_id )
      ?  Socialtext::User->new( user_id => $system_unique_id )
        : undef;
};

# by creator apply
my $by_creator_apply = sub {
    my $rows             = shift;
    my $system_unique_id = $rows->[0];

    # short circuit to not hand back undefs in a list context
    return ( defined $system_unique_id )
      ?  Socialtext::User->new( user_id => $system_unique_id )
        : undef;
};

# by workspace with roles apply
my $by_workspace_with_roles_apply = sub {
    my $rows     = shift;
    my $user_row = $rows->[0];
    my $role_row = $rows->[1];

    # short circuit to not hand back undefs in a list context
    return undef if !$user_row;

    return [
        Socialtext::User->new(
            user_id => $user_row->select('system_unique_id')
        ),
        Socialtext::Role->new(
            role_id => $role_row->select('role_id')
        )
    ];
};

# by workspace with roles apply, ordered by creator
my $by_workspace_with_roles_ordered_by_creator_apply = sub {
    my $rows     = shift;
    my $user_id = $rows->[0];
    my $role_id = $rows->[1];

    # short circuit to not hand back undefs in a list context
    return undef if !$user_id;

    return [
        Socialtext::User->new(
            user_id => $user_id
        ),
        Socialtext::Role->new(
            role_id => $role_id
        )
    ];
};

sub Search {
    my $class = shift;
    my $search_term = shift;

    return $class->_aggregate('Search', $search_term);
}

my %LimitAndSortSpec = (
    limit      => SCALAR_TYPE( default => 0 ),
    offset     => SCALAR_TYPE( default => 0 ),
    order_by   => SCALAR_TYPE(
        regex   => qr/^(?:username|workspace_count|creation_datetime|creator)$/,
        default => 'username',
    ),
    sort_order => SCALAR_TYPE(
        regex   => qr/^(?:ASC|DESC)$/i,
        default => undef,
    ),
);

{
    Readonly my $spec => { %LimitAndSortSpec };
    sub All {
        # Returns an iterator of Socialtext::User objects
        my $class = shift;
        my %p = validate( @_, $spec );

        # we pick our apply before ever getting to _SortedQuery
        my $apply;
        if ($p{order_by} eq 'workspace_count') {
            $apply = $by_workspace_count_apply;
        }
        elsif ($p{order_by} eq 'creator') {
            $apply = $by_creator_apply;
        }

        return $class->_SortedQuery(%p, apply => $apply);
    }
}

{
    Readonly my $spec => {
        %LimitAndSortSpec,
        order_by => SCALAR_TYPE(
            regex   => qr/^(?:username|creation_datetime|creator)$/,
            default => 'username',
        ),
        account_id => SCALAR_TYPE,
    };
    sub ByAccountId {
        # Returns an iterator of Socialtext::User objects
        my $class = shift;
        my %p = validate( @_, $spec );

        my $uid_table = Socialtext::Schema->Load()->table('UserId');
        my $uwr_table  = Socialtext::Schema->Load()->table('UserWorkspaceRole');
        my $ws_table   = Socialtext::Schema->Load()->table('Workspace');

        my @join  = (
            [ $uid_table, $uwr_table ],
            [ $uwr_table, $ws_table ],
        );

        my @where = ( $ws_table->column('account_id'), '=', $p{account_id} );

        # we pick our apply before ever getting to _SortedQuery
        my $apply;
        if ($p{order_by} eq 'workspace_count') {
            $apply = $by_workspace_count_apply;
        }
        elsif ($p{order_by} eq 'creator') {
            $apply = $by_creator_apply;
        }


        return $class->_SortedQuery( %p, join => \@join, where => \@where, apply => $apply );
    }
}

{
    Readonly my $spec => {
        %LimitAndSortSpec,
        order_by   => SCALAR_TYPE(
            regex   => qr/^(?:username|creation_datetime|creator|role_name)$/,
            default => 'username',
        ),
        workspace_id => SCALAR_TYPE,
    };

    sub ByWorkspaceIdWithRoles {
        # Returns an iterator of [Socialtext::User, Socialtext::Role] arrays
        my $class = shift;
        my %p = validate( @_, $spec );

        my $uid_table = Socialtext::Schema->Load()->table('UserId');
        my $uwr_table  = Socialtext::Schema->Load()->table('UserWorkspaceRole');
        my $role_table = Socialtext::Schema->Load()->table('Role');

        my @join  = (
            [ $uid_table, $uwr_table ],
            [ $uwr_table, $role_table ],
        );

        my @where
            = ( $uwr_table->column('workspace_id'), '=', $p{workspace_id} );

        # we pick our apply before ever getting to _SortedQuery
        my $apply = $by_workspace_with_roles_apply;
        if ($p{order_by} eq 'creator') {
            $apply = $by_workspace_with_roles_ordered_by_creator_apply;
        }

        return $class->_SortedQuery(
            %p, select => [ $role_table ], join => \@join, where => \@where,
            apply => $apply,
        );
    }
}

{
    Readonly my $spec => {
        %LimitAndSortSpec,
        username => SCALAR_TYPE( regex => qr/\S/ ),
    };
    sub ByUsername {
        # Returns an iterator of Socialtext::User objects
        my $class = shift;
        my %p = validate( @_, $spec );

        my $uid_table = Socialtext::Schema->Load()->table('UserId');

        # REVIEW: Do we handle usernames with '%' in them very well? Mebbe not
        my @where = ( $uid_table->column('driver_username'), 'LIKE',
            '%' . lc $p{username} . '%' );

        # we pick our apply before ever getting to _SortedQuery
        my $apply;
        if ($p{order_by} eq 'workspace_count') {
            $apply = $by_workspace_count_apply;
        }
        elsif ($p{order_by} eq 'creator') {
            $apply = $by_creator_apply;
        }

        return $class->_SortedQuery(%p, where => \@where, apply => $apply);
    }
}

sub _SortedQuery {
    my $class = shift;
    my %p = @_;

    my %select;
    if ( $p{select} ) {
        $select{select} = $p{select};
    }

    my %limit;
    if ( $p{limit} ) {
        $limit{limit} = [ @p{ 'limit', 'offset' } ];
    }

    my %where;
    if ( $p{where} ) {
        $where{where} = $p{where};
    }

    my $schema = Socialtext::Schema->Load();
    my $uid_table = $schema->table('UserId');

    my $sort_order = (
        defined $p{sort_order}
        ? uc $p{sort_order}
        : $p{order_by} eq 'creation_datetime'
        ? 'DESC'
        : 'ASC'
    );

    my $apply = $p{apply} ? $p{apply} : sub {
        my $row = shift;
        return Socialtext::User->new(
            user_id => $row->select('system_unique_id')
        );
    };

    my @order_by;
    if ( $p{order_by} eq 'username' ) {
        @order_by = ( $uid_table->column('driver_username'), $sort_order );
    }
    elsif ( $p{order_by} eq 'creation_datetime' ) {
        my $um_table = Socialtext::Schema->Load()->table('UserMetadata');
        push @{ $p{join} }, [ $uid_table, $um_table ];

        @order_by = (
            $um_table->column('creation_datetime'), $sort_order,
            $uid_table->column('driver_username'), 'ASC',
        );
    }
    # Only valid if this was called via ByWorkspaceIdWithRoles in which
    # case Role is already in the join
    elsif ( $p{order_by} eq 'role_name' ) {
        my $role_table = Socialtext::Schema->Load()->table('Role');

        @order_by = (
            $role_table->column('name'), $sort_order,
            $uid_table->column('driver_username'), 'ASC',
        );
    }
    elsif ( $p{order_by} eq 'creator' ) {
        return $class->_ByCreator(
            sort_order => $sort_order,
            join       => $p{join},
            apply      => $apply,
            %select,
            %where,
            %limit,
        );
    }
    elsif ( $p{order_by} eq 'workspace_count' ) {
        return $class->_ByWorkspaceCount(
            sort_order => $sort_order,
            join       => $p{join},
            apply      => $apply,
            %select,
            %where,
            %limit,
        );
    }

    my @select =
        $p{select}
        ? ( $uid_table, @{ $p{select} } )
        : $uid_table;

    my @join =
        $p{join}
        ? @{ $p{join} }
        : $uid_table;

    return Socialtext::MultiCursor->new(
        iterables => [
            $schema->join(
                distinct => \@select,
                join     => \@join,
                %where,
                order_by => \@order_by,
                %limit,
            )
        ],
        apply => $apply
    );
}

sub _ByCreator {
    my $class = shift;
    my %p = @_;

    my $schema = Socialtext::Schema->Load();
    my $uid_table = $schema->table('UserId');
    my $uid_table2 = $uid_table->alias;
    my $um_table  = $schema->table('UserMetadata');

    my @join;
    @join = @{ $p{join} } if $p{join};

    my $fk = Alzabo::Runtime::ForeignKey->new(
        columns_from => [ $um_table->columns( 'created_by_user_id' ) ],
        columns_to   => [ $uid_table2->columns( 'system_unique_id' ) ],
    );
    push @join,
        [ $uid_table, $um_table ],
        [ 'left_outer_join', $um_table, $uid_table2, $fk ];

    my %where = $p{where} ? ( where => $p{where} ) : ();
    my %limit = $p{limit} ? ( limit => $p{limit} ) : ();

    my @select = DISTINCT( $uid_table->column( 'system_unique_id' ) );
    if ( $p{select} ) {
        push @select, map { $_->primary_key() } @{ $p{select} };
    }
    # The aliased table's username column must be present in the
    # SELECT in order for us to use it in ORDER BY for Pg to be happy.
    push @select, 
        $uid_table->column('driver_username'),
        $uid_table2->column('driver_username');

    my $select = $schema->select(
        select   => \@select,
        join     => \@join,
        %where,
        order_by => [
            $uid_table2->column('driver_username'), $p{sort_order},
            $uid_table->column('driver_username'), 'ASC',
        ],
        %limit,
    );

    return Socialtext::MultiCursor->new(
        iterables => [$select],
        apply => $p{apply}
    );
}

# TODO - this simply doesn't do the right thing if called via
# ByAccountId or ByWorkspaceIdWithRoles - making it work requires even
# more SQL gyrations, something like
#
# The query for ByWorkspaceIdWithRoles is basically this:
#
# SELECT U.user_id, R.role_id, COUNT( DISTINCT(UWR.workspace_id) )
#   FROM User, UserWorkspaceRole, Role
#  WHERE UWR.user_in IN
#        ( SELECT UWR.user_id
#            FROM UWR
#           WHERE UWR.workspace_id = ? )
#   AND [ join tables together ]
# GROUP BY U.user_id, U.username, R.role_id
# ORDER BY ...
#
# The one for ByAccountID is similar. The key in both is get the
# workspace_count for _all_ workspaces, while limited the selection of
# users to those in a specified account or workspace.
sub _ByWorkspaceCount {
    my $class = shift;
    my %p = @_;

    my $schema = Socialtext::Schema->Load();
    my $uid_table = $schema->table('UserId');
    my $uwr_table = $schema->table('UserWorkspaceRole');

    my @join;
    @join = @{ $p{join} } if $p{join};

    # If UserWorkspaceRole is in the join already then joining it
    # again via a left outer join will produce a very wacky query
    unless ( grep { $_->name eq 'UserWorkspaceRole' } map { @$_} @join ) {
        push @join,
            [ left_outer_join => $uid_table, $uwr_table ];
    }

    my %where = $p{where} ? ( where => $p{where} ) : ();
    my %limit = $p{limit} ? ( limit => $p{limit} ) : ();

    my $count = COUNT( DISTINCT( $uwr_table->column('workspace_id') ) );
    my $select = $schema->select(
        select   => [ $uid_table->column('system_unique_id'), $count ],
        join     => \@join,
        %where,
        order_by => [ $count, $p{sort_order}, $uid_table->column('driver_username'), 'ASC' ],
        group_by => [ $uid_table->column('system_unique_id'), $uid_table->column('driver_username') ],
        %limit,
    );

    return Socialtext::MultiCursor->new(
        iterables => [$select],
        apply => $p{apply}
    );
}

{
    Readonly my $spec => { username => SCALAR_TYPE( regex => qr/\S/ ) };
    sub CountByUsername {
        my $class = shift;
        my %p = validate( @_, $spec );

        my $uid_table = Socialtext::Schema->Load()->table('UserId');

        return $uid_table->row_count(
            where => [ $uid_table->column('driver_username'), 'LIKE', '%' . lc $p{username} . '%' ],
        );
    }
}

sub Count {
    my $class = shift;
    my $uid_table = Socialtext::Schema->Load()->table('UserId');
    return $uid_table->row_count;
}

# Confirmation methods

# REVIEW - I don't really like this method name, "info" is so generic.
{
    my $spec = { is_password_change => BOOLEAN_TYPE( default => 0 ) };

    sub set_confirmation_info {
        my $self = shift;
        my %p    = validate( @_, $spec );

        my $hash = $self->_generate_confirmation_hash();

        my $expires = DateTime->now()->add( days => 14 );
        my %vals = (
            sha1_hash           => $hash,
            expiration_datetime =>
                DateTime::Format::Pg->format_timestamptz($expires),
            is_password_change  => $p{is_password_change},
        );

        if ( my $uce = $self->_uce_row() ) {
            $uce->update(%vals);
        }
        else {
            my $uce_table
                = Socialtext::Schema->Load()->table('UserEmailConfirmation');
            $uce_table->insert(
                values => { user_id => $self->user_id, %vals } );
        }
    }
}

# Reuse existing hashes before making new ones.  This helps avoid issues like
# RT 20767, where future hashes were clobering older ones when a non-existant
# user was invited to multiple workspaces.
sub _generate_confirmation_hash {
    my $self = shift;
    my $hash = eval { $self->confirmation_hash() };
    $hash ||= Digest::SHA1::sha1_base64(
        $self->user_id, time,
        Socialtext::AppConfig->MAC_secret()
    );
    return $hash;
}

sub confirmation_hash {
    my $self = shift;

    my $uce = $self->_uce_row();

    return unless $uce;

    return $uce->select('sha1_hash');
}

sub confirmation_is_for_password_change {
    my $self = shift;

    my $uce = $self->_uce_row();

    return unless $uce;

    return $uce->select('is_password_change');
}

# REVIEW - does this belong in here, or maybe a higher level library
# like one for all of our emails? I dunno.
sub send_confirmation_email {
    my $self = shift;

    return unless $self->_uce_row();

    my $renderer = Socialtext::TT2::Renderer->instance();

    my $uri = $self->confirmation_uri();

    my %vars = (
        confirmation_uri => $uri,
        appconfig        => Socialtext::AppConfig->instance(),
    );

    my $text_body = $renderer->render(
        template => 'email/email-address-confirmation.txt',
        vars     => \%vars,
    );

    my $html_body = $renderer->render(
        template => 'email/email-address-confirmation.html',
        vars     => \%vars,
    );

    # XXX if we add locale per workspace, we have to get the locale from hub.
    my $locale = system_locale();
    my $email_sender = Socialtext::EmailSender::Factory->create($locale);
    $email_sender->send(
        to        => $self->name_and_email(),
        subject   => loc('Please confirm your email address to register with Socialtext'),
        text_body => $text_body,
        html_body => $html_body,
    );
}

sub send_confirmation_completed_email {
    my $self = shift;

    return if $self->_uce_row();

    my $renderer = Socialtext::TT2::Renderer->instance();

    my $ws = $self->workspaces->next();

    my %vars;
    my $subject;
    # A user who self-registers may not be a member of any workspaces.
    if ($ws) {
        %vars = (
            title => $ws->title(),
            uri   => $ws->uri(),
        );

        $subject = loc('You can now login to the [_1] workspace', $ws->title());
    }
    else {
        # REVIEW - duplicated form ST::UserSettingsPlugin - where does
        # this belong, maybe AppConfig?
        my $app_name =
            Socialtext::AppConfig->is_appliance()
            ? 'Socialtext Appliance'
            : 'Socialtext';

        %vars = (
            title => $app_name,
            uri   => Socialtext::URI::uri( path => '/nlw/login.html' ),
        );

        $subject = loc("You can now login to the [_1] application", $app_name);
    }

    $vars{user}      = $self;
    $vars{appconfig} = Socialtext::AppConfig->instance();

    my $text_body = $renderer->render(
        template => 'email/email-address-confirmation-completed.txt',
        vars     => \%vars,
    );

    my $html_body = $renderer->render(
        template => 'email/email-address-confirmation-completed.html',
        vars     => \%vars,
    );
    my $locale = system_locale();
    my $email_sender = Socialtext::EmailSender::Factory->create($locale);
    $email_sender->send(
        to        => $self->name_and_email(),
        subject   => $subject,
        text_body => $text_body,
        html_body => $html_body,
    );
}

sub send_password_change_email {
    my $self = shift;

    return unless $self->_uce_row();

    my $renderer = Socialtext::TT2::Renderer->instance();

    my $uri = $self->confirmation_uri();

    my %vars = (
        appconfig        => Socialtext::AppConfig->instance(),
        confirmation_uri => $uri,
    );

    my $text_body = $renderer->render(
        template => 'email/password-change.txt',
        vars     => \%vars,
    );

    my $html_body = $renderer->render(
        template => 'email/password-change.html',
        vars     => \%vars,
    );
    my $locale = system_locale();
    my $email_sender = Socialtext::EmailSender::Factory->create($locale);
    $email_sender->send(
        to        => $self->name_and_email(),
        subject   => loc('Please follow these instructions to change your Socialtext password'),
        text_body => $text_body,
        html_body => $html_body,
    );
}

sub confirmation_uri {
    my $self = shift;

    return unless $self->requires_confirmation;

    return Socialtext::URI::uri(
        path  => '/nlw/submit/confirm_email',
        query => { hash => $self->confirmation_hash() },
    );
}

sub requires_confirmation {
    my $self = shift;

    return ($self->_uce_row()) ? 1 : 0;
}

sub confirmation_has_expired {
    my $self = shift;

    my $uce = $self->_uce_row();

    return unless $uce;

    return 1 if
        DateTime::Format::Pg->parse_timestamptz( $uce->select('expiration_datetime' ) )
        < DateTime->now();
}

sub confirm_email_address {
    my $self = shift;

    my $uce = $self->_uce_row();

    return unless $uce;

    my $is_password_change = $uce->select('is_password_change');

    $uce->delete();

    # REVIEW - this works around what might be a bug (or maybe not) in
    # Alzabo. If a row object is deleted, it stays in the cache but
    # its state is deleted (this can be checked with is_deleted()). I
    # think it should probably be removed from the cache but I'm not
    # 100% that's right.
    Alzabo::Runtime::UniqueRowCache->clear_table( $uce->table() )
        if Alzabo::Runtime::UniqueRowCache->can('clear_table');

    $self->send_confirmation_completed_email()
        unless $is_password_change;
}

sub _uce_row {
    my $self =shift;

    my $uce_table = Socialtext::Schema->Load()->table('UserEmailConfirmation');
    return $uce_table->row_by_pk( pk => $self->user_id );
}

1;

__END__

=head1 NAME

Socialtext::User - A Socialtext user object

=head1 SYNOPSIS

  use Socialtext::User;

  my $user = Socialtext::User->new( user_id => $user_id );

  my $user = Socialtext::User->new( username => $username );

  my $user = Socialtext::User->new( email_address => $email_addres );

=head1 DESCRIPTION

This class provides methods for dealing with abstract users.

=head1 METHODS

=head2 Socialtext::User->new(PARAMS)

Looks for an existing user matching PARAMS and returns a
C<Socialtext::User> object representing that user if it exists.

The user object comprises two hashes: a homunculus, representing the user's
credential data (username, password, email address, first name, and last
name), and application-specific C<Socialtext::UserMetadata> (last login time,
creation time, who created the user, &c).

PARAMS can be I<one> of:

=over 4

=item * user_id => $user_id

=item * username => $username

=item * email_address => $email_address

=back

=head2 Socialtext::User->new_homunculus(PARAMS)

Looks for an existing user matching PARAMS and returns just the homunculus
object (an instance of the particular class which authenticated the
credentials).

PARAMS can be I<one> of:

=over 4

=item * user_id => $user_id

=item * username => $username

=item * email_address => $email_address

=back

=head2 Socialtext::User->create(PARAMS)

Attempts to create a user with the given information and returns a new
C<Socialtext>::User object representing the new user.

PARAMS can include:

=over 4

=item * username - required

=item * email_address - required

=item * password - see below for default

Normally, the value for "password" should be provided in unencrypted
form.  It will be stored in the DBMS in C<crypt()>ed form.  If you
must pass in a crypted password, you can also pass C<< no_crypt => 1
>> to the method.

The password must be at least six characters long.

If no password is specified, the password will be stored as the string
"*none*", unencrypted. This will cause the C<<
$user->has_valid_password() >> method to return false for this user.

=item * require_password - defaults to false

If this is true, then the absence of a "password" parameter is
considered an error.

=item * first_name

=item * last_name

=item * creation_datetime - defaults to CURRENT_TIMESTAMP

=item * last_login_datetime

=item * email_address_at_import - defaults to "email_address"

=item * created_by_user_id - defaults to SystemUser()->user_id()

=item * is_business_admin - defaults to false

=item * is_technical_admin - defaults to false

=item * is_system_created - defaults to false

=back

=head2 $class->base_package

Returns the name of the package (used by the Socialtext::MultiPlugin base when
determining driver classes

=head2 $user->can_update_store()

Returns true if the user factory supports updates.

=head2 $user->update_store(PARAMS)

Updates the user's information with the new key/val pairs passed in.

=head2 $user->user_id()

=head2 $user->username()

=head2 $user->email_address()

=head2 $user->first_name()

=head2 $user->last_name()

=head2 $user->driver_name()

=head2 $user->creation_datetime()

=head2 $user->last_login_datetime()

=head2 $user->created_by_user_id()

=head2 $user->is_business_admin()

=head2 $user->is_technical_admin()

=head2 $user->is_system_created()

Returns the corresponding attribute for the user.

=head2 $user->delete()

By default, this method simply throws an exception. In almost all
cases, users should not be deleted, as they are foreign keys for too
many other tables, and even if a user is no longer active, they are
still likely to be needed when looking up page authors and other
information.

If you pass C<< force => 1 >> this will force the deletion through.

As an alternative to deletion, you can block a user from logging in by
setting their password to some string and passing C<< no_crypt => 1 >>
to C<update()>

=head2 $user->to_hash()

Returns a hash reference representation of the user, suitable for using with
JSON, YAML, etc.  B<WARNING:> The encryted password is included in this hash,
and should usually be removed before passing the hash over the threshold.

=head2 $user->password_is_correct($pw)

Returns a boolean indicating whether or not the given password is
correct.

=head2 $user->has_valid_password()

Returns true if the user has a valid password.

For now, this is defined as any password not matching "*none*".

=head2 Socialtext::User->ValidatePassword( password => $pw )

Given a password, this returns a list of error messages if the
password is invalid.

=head2 $user->set_technical_admin($value)

Updates the is_technical_admin for the user to $value (0 or 1).

=head2 $user->set_business_admin($value)

Updates the is_business_admin for the user to $value (0 or 1).

=head2 $user->record_login()

Updates the last_login_datetime for the user to the current datetime.

=head2 $user->name_and_email()

Returns the user's name and email address in a format suitable for use
in email headers, such as C<< "John Doe" <john@example.com> >>.

=head2 $user->best_full_name( workspace => $workspace )

If the user has a first name and/or last name in the DBMS, then this
method returns the two fields separated by a single space. If neither
is set, then this returns the user's email address.

The "workspace" argument is optional, but if it is given, then the
email address will be masked according to the settings of the given
workspace.

=head2 $user->name_for_email()

Returns the user's name and email, in a format suitable for use in
email headers.

=head2 $user->guess_real_name()

Returns the a guess at the user's real name, using the first name
and/or last name from the DBMS if possible. Otherwise it simply uses
the portion of the email address up to the at (@) symbol.

=head2 $user->creation_datetime_object()

Returns a new C<DateTime.pm> object for the user's creation datetime.

=head2 $user->last_login_datetime_object()

Returns a new C<DateTime.pm> object for the user's last login
datetime. This may be a C<DateTime::Infinite::Past> object if the user
has never logged in.

=head2 $user->creator()

Returns a C<Socialtext::User> object for the user which created this
user.

=head2 $user->workspace_count()

Returns the number of workspaces of which the user is a member.

=head2 $user->workspaces(PARAMS)

Returns a cursor of the workspaces of which the user is a member,
ordered by workspace name.

PARAMS can include:

=over 4

=item * selected_only

If this is true, then only workspaces for which UserWorkspaceRole.is_selected
is true are returned.

=item * exclude

This should be an array reference of workspace ids to be excluded from
the query.

REVIEW - this is somewhat nasty and only used in one spot -
Socialtext::DuplicatePagePlugin

=back

=head2 $user->workspaces_with_selected()

Returns a cursor of the C<Socialtext::Workspace> and
C<Socialtext::UserWorkspaceRole> object for the workspace of which the
user is a member, ordered by workspace name.

REVIEW - better name needed

=head2 $user->workspace_is_selected( workspace => $workspace )

Returns a boolean indicating whether or not the given workspace is
selected.

=head2 $user->set_selected_workspaces( workspaces => [ $ws1, $ws2 ] );

Given an array reference of C<Socialtext::Workspace> objects, this
sets UserWorkspaceRole.is_selected for each workspace to true, and
false for all other workspaces of which the user is a member.

=head2 $user->is_authenticated()

Returns a boolean indicating whether the user is an authenticated user
(not the guest user).

=head2 $user->is_guest()

Returns a boolean indicating whether the user is the guest user.

=head2 $user->is_deleted()

Returns a boolean indicating whether the user is present in our
system, but cannot be looked up for some reason.

=head2 $user->default_role()

Returns the default role for the user absent an explicit role
assignment. This will be either "guest" or "authenticated_user".

=head2 Socialtext::User->minimal_interface()

Returns the minimal keys necessary for User Factory plugins to implement.

=head2 Socialtext::User->Guest()

Returns the user object for the "guest user", which is used when an
end user comes to the application without authentication.

=head2 Socialtext::User->SystemUser()

Returns the user object for the "system user", which should be used as
the user for operations where a user is needed but there is no end
user, like operations done from the CLI (creating a workspace, for
example).

=head2 Socialtext::User->FormattedEmail($first_name, $last_name, $email_address)

Returns a formatted email address from the parameters passed in. Will attempt
to construct a "pretty" presentation:

=over 4

=item "Zachery Bir" <zac.bir@socialtext.com>

=item "Zachery" <zac.bir@socialtext.com>

=item "Bir" <zac.bir@socialtext.com>

=item <zac.bir@socialtext.com>

=back

=head2 Socialtext::User->All(PARAMS)

Returns a cursor for all the users in the system. It accepts the
following parameters:

=over 4

=item * limit and offset

These parameters can be used to add a C<LIMIT> clause to the query.

=item * order_by - defaults to "username"

This must be one "username", "workspace_count", "creation_datetime",
or "creator".

=item * sort_order - "ASC" or "DESC"

This defaults to "ASC" except when C<order_by> is "creation_datetime",
in which case it defaults to "DESC".

=back

=head2 Socialtext::User->ByAccountId(PARAMS)

Returns a cursor for all the users in a specified account.

This method accepts the same parameters as C<< Socialtext::User->All()
>>, but requires an additional "account_id" parameter. The C<order_by>
parameter cannot be "workspace_count".

=head2 Socialtext::User->ByWorkspaceIdWithRoles(PARAMS)

This method returns a cursor that of the user and their role in the
specified workspace.

This accepts the same parameters as C<< Socialtext::User->All() >>,
but requires an additional "workspace_id" parameter. When this method
is called, the C<order_by> parameter may also be "role_name". The
C<order_by> parameter cannot be "workspace_count".

=head2 Socialtext::User->ByUsername(PARAMS)

Returns a cursor for all the users matching the specified string.

This accepts the same parameters as C<< Socialtext::User->All() >>,
but requires an additional "username" parameter. Any users containing
the specified string anywhere in their username will be returned.

=head2 Socialtext::User->Count()

Returns a count of all users.

=head2 Socialtext::User->CountByUsername( username => $username )

Returns the number of users in the system containing the
specified string anywhere in their username.

=head2 Socialtext::User->Search( $search_string )

Returns an aggregated cursor of Socialtext::User objects which match
$search_string on any of username, email_address, first_name, or
last_name.

=head2 $user->set_confirmation_info()

Creates a confirmation hash and an expiration date for this user in
the UserEmailConfirmation table. When this exists, the C<<
$user->requires_confirmation() >> will return true.

This method accepts a single boolean argument, "is_password_change",
which defaults to false. Set this to true if the confirmation is being
set to allow a user to change their password.

Confirmations expire fourteen days after they are created.

If the user already has an existing confirmation row, then its
expiration datetime is updated to one day after the datetime at which
the method was called.

=head2 $user->requires_confirmation()

This returns true if there is a row for this user in the
UseEmailConfirmation table.

=head2 $user->confirmation_is_for_password_change()

This returns true if the user requires confirmation, and this is for
the purpose of allow them to change their password.

=head2 $user->confirmation_hash()

Returns the hash value which will confirm this user's email address,
if one exists.

=head2 $user->confirmation_uri()

This is the URI to confirm the user's email address. If the user is
already confirmation, it returns false.

=head2 $user->confirmation_has_expired()

Returns a boolean indicating whether or not the user's confirmation
hash has expired.

=head2 $user->send_confirmation_email()

If the user has a row in UserEmailConfirmation, this method sends them
an email with a link they can use to confirm their email address.

=head2 $user->send_confirmation_completed_email()

If the user I<does not> have a row in UserEmailConfirmation, this
method sends them an email saying that their email confirmation has
been completed.

=head2 $user->send_password_change_email()

If the user has a row in UserEmailConfirmation, this method sends them
an email with a link they can use to change their password.

=head2 $user->confirm_email_address()

Marks the user's email address as confirmed by deleting the row for
the user in UserConfirmationEmail.

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005 Socialtext, Inc., All Rights Reserved.


=cut
