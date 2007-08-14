# @COPYRIGHT@
package Socialtext::Schema;

use strict;
use warnings;

our $VERSION = '0.01';

use Alzabo::Create;
use Alzabo::Runtime;
use Socialtext::AppConfig;


{
    no warnings 'redefine';

    # We want to be able to load the schema without connecting it, but
    # on the flipside we want to try to connect to the dbms
    # transparently whenever we need to, without requiring the end
    # user of our libraries to explicitly connect.
    #
    # This needs to be done at a fairly low level in order to catch
    # the moment when we know we need a connection but do not have
    # one. In the future, we may want to add some sort of hook to
    # Alzabo that can be called when it detects an attempt to do
    # something that needs to talk to the DBMS before
    # Alzabo::Schema->connect() has been called.
    #
    # For now, this is the simplest solution, though it's a bit of a
    # nasty hack.
    sub Alzabo::Driver::_ensure_valid_dbh {
        my $self = shift;

        if ( ! $self->{dbh}
             and $self->{schema}->name eq 'NLW' ) {
            Socialtext::Schema->_Connect();
        }

        $self->{dbh} = $self->_dbi_connect( $self->{connect_params} )
            if $$ != $self->{connect_pid};
    }
}

my $Schema;
sub Load {
    unless ($Schema) {
        my $create = SchemaObject();
        $Schema = $create->runtime_clone;

        # FIXME - This is a nasty hack that should be fixed by
        # changing Alzabo so that it supports other ways of creating
        # runtime schemas besides simply loading them from schema
        # files.
        $Schema->{driver} = Alzabo::Driver->new( rdbms => 'PostgreSQL',
                                                 schema => $Schema );
        $Schema->{rules} = Alzabo::RDBMSRules->new( rdbms => 'PostgreSQL' );
        $Schema->{sql} = Alzabo::SQLMaker->load( rdbms => 'PostgreSQL' );

        $Schema->prefetch_all_but_blobs();

        $Schema->set_quote_identifiers(1);
    }

    return $Schema;
}

sub LoadAndConnect {
    my $schema = Load();

    CheckDBH();

    return $schema;
}

sub CheckDBH {
    my $schema = Load();

    _Connect()
        unless $schema->driver()->handle()
               and $schema->driver()->handle()->ping();
}

sub _Connect {
    my $schema = Load();

    my %connect_params = Socialtext::AppConfig->db_connect_params();
    for my $p ( keys %connect_params ) {
        my $meth = "set_$p";
        $schema->$meth( $connect_params{$p} );
    }

    # Leaving pg_server_prepare on causes strange random errors of the
    # form 'prepared statement "dbdpg_3" does not exist' every 10-20
    # requests. This feature only exists for Pg 8.0+, so it's not an
    # issue with what's on our prod/staging systems at present anyway,
    # but I have 8.0 locally (Dave).
    $schema->connect( pg_server_prepare => 0,
                      pg_enable_utf8    => 1,
                    );
}

sub SchemaObject {
    my $schema = Alzabo::Create::Schema->new( name  => 'NLW',
                                              rdbms => 'PostgreSQL',
                                            );

    {
        my $table = $schema->make_table
            ( name       => 'User',
            );
        $table->make_column
            ( name           => 'user_id',
              type           => 'INT8',
              sequenced      => 1,
              primary_key    => 1,
            );
        $table->make_column
            ( name           => 'username',
              type           => 'VARCHAR',
              length         => 250,
            );
        $table->make_column
            ( name           => 'email_address',
              type           => 'VARCHAR',
              length         => 250,
            );
        $table->make_column
            ( name           => 'password',
              type           => 'VARCHAR',
              length         => 40,
            );
        $table->make_column
            ( name           => 'first_name',
              type           => 'VARCHAR',
              default        => '',
              default_is_raw => 0,
              length         => 200,
            );
        $table->make_column
            ( name           => 'last_name',
              type           => 'VARCHAR',
              default        => '',
              default_is_raw => 0,
              length         => 200,
            );
        $table->make_index
            ( columns  => [ $schema->table( 'User' )->columns( 'username' ) ],
              unique   => 1,
              function => 'lower(username)',
            );
        $table->make_index
            ( columns  => [ $schema->table( 'User' )->columns( 'email_address' ) ],
              unique   => 1,
              function => 'lower(email_address)',
            );
    }

    {
        my $table = $schema->make_table
            ( name       => 'UserId',
            );
        $table->make_column
            ( name           => 'system_unique_id',
              type           => 'INT8',
              sequenced      => 1,
              primary_key    => 1,
            );
        $table->make_column
            ( name           => 'driver_key',
              type           => 'VARCHAR',
              length         => 250,
            );
        $table->make_column
            ( name           => 'driver_unique_id',
              type           => 'VARCHAR',
              length         => 250,
            );
        $table->make_column
            ( name           => 'driver_username',
              type           => 'VARCHAR',
              length         => 250,
              nullable       => 1,
            );
    }

    {
        my $table = $schema->make_table
            ( name       => 'UserMetadata',
            );
        $table->make_column
            ( name           => 'user_id',
              type           => 'INT8',
              primary_key    => 1,
            );
        $table->make_column
            ( name           => 'creation_datetime',
              type           => 'TIMESTAMPTZ',
              default        => 'CURRENT_TIMESTAMP',
              default_is_raw => 1,
            );
        $table->make_column
            ( name           => 'last_login_datetime',
              type           => 'TIMESTAMPTZ',
              default        => '-infinity',
            );
        $table->make_column
            ( name           => 'email_address_at_import',
              type           => 'VARCHAR',
              nullable       => 1,
              length         => 250,
            );
        $table->make_column
            ( name           => 'created_by_user_id',
              type           => 'INT8',
              nullable       => 1,
            );
        $table->make_column
            ( name           => 'is_business_admin',
              type           => 'BOOLEAN',
              default        => 'f',
            );
        $table->make_column
            ( name           => 'is_technical_admin',
              type           => 'BOOLEAN',
              default        => 'f',
            );
        $table->make_column
            ( name           => 'is_system_created',
              type           => 'BOOLEAN',
              default        => 'f',
            );
        $table->make_index
            ( columns  => [ $schema->table( 'UserMetadata' )->columns( 'user_id' ) ],
              unique   => 1,
            );
    }

    {
        my $table = $schema->make_table
            ( name       => 'UserEmailConfirmation',
            );
        $table->make_column
            ( name           => 'user_id',
              type           => 'INT8',
              primary_key    => 1,
            );
        $table->make_column
            ( name           => 'sha1_hash',
              type           => 'VARCHAR',
              length         => 27,
              comment        => 'An SHA1 hash, base64 encoded',
            );
        $table->make_column
            ( name           => 'expiration_datetime',
              type           => 'TIMESTAMPTZ',
              default        => '-infinity',
            );
        $table->make_column
            ( name           => 'is_password_change',
              type           => 'BOOLEAN',
              default        => 'f',
            );
        $table->make_index
            ( columns  => [ $table->columns( 'sha1_hash' ) ],
              unique   => 1,
            );
    }

    {
        my $table = $schema->make_table
            ( name       => 'Workspace',
            );
        $table->make_column
            ( name           => 'workspace_id',
              type           => 'INT8',
              sequenced      => 1,
              primary_key    => 1,
            );
        $table->make_column
            ( name           => 'name',
              type           => 'VARCHAR',
              length         => 30,
            );
        $table->make_column
            ( name           => 'title',
              type           => 'TEXT',
            );
        $table->make_column
            ( name           => 'logo_uri',
              type           => 'TEXT',
              default        => '',
            );
        $table->make_column
            ( name           => 'homepage_weblog',
              type           => 'TEXT',
              default        => '',
            );
        $table->make_column
            ( name           => 'email_addresses_are_hidden',
              type           => 'BOOLEAN',
              default        => 'f',
            );
        $table->make_column
            ( name           => 'unmasked_email_domain',
              type           => 'VARCHAR',
              default        => '',
              length         => 250,
            );
        $table->make_column
            ( name           => 'prefers_incoming_html_email',
              type           => 'BOOLEAN',
              default        => 'f',
            );
        $table->make_column
            ( name           => 'incoming_email_placement',
              type           => 'VARCHAR',
              default        => 'bottom',
              length         => 10,
              comment        => 'One of \'top\', \'bottom\', or \'replace\'',
            );
        $table->make_column
            ( name           => 'allows_html_wafl',
              type           => 'BOOLEAN',
              default        => 't',
            );
        $table->make_column
            ( name           => 'email_notify_is_enabled',
              type           => 'BOOLEAN',
              default        => 't',
            );
        $table->make_column
            ( name           => 'sort_weblogs_by_create',
              type           => 'BOOLEAN',
              default        => 'f',
              comment        => 'The defualt is to sort by last update datetime',
            );
        $table->make_column
            ( name           => 'external_links_open_new_window',
              type           => 'BOOLEAN',
              default        => 't',
            );
        $table->make_column
            ( name           => 'basic_search_only',
              type           => 'BOOLEAN',
              default        => 'f',
            );
        $table->make_column
            ( name           => 'enable_unplugged',
              type           => 'BOOLEAN',
              default        => 'f',
            );
        $table->make_column
            ( name           => 'skin_name',
              type           => 'VARCHAR',
              default        => 'st',
              length         => 30,
            );
        $table->make_column
            ( name           => 'custom_title_label',
              type           => 'VARCHAR',
              default        => '',
              length         => 100,
            );
        $table->make_column
            ( name           => 'header_logo_link_uri',
              type           => 'VARCHAR',
              default        => 'http://www.socialtext.com/',
              length         => 100,
            );
        $table->make_column
            ( name           => 'show_welcome_message_below_logo',
              type           => 'BOOLEAN',
              default        => 'f',
            );
        $table->make_column
            ( name           => 'show_title_below_logo',
              type           => 'BOOLEAN',
              default        => 't',
            );
        $table->make_column
            ( name           => 'comment_form_note_top',
              type           => 'TEXT',
              default        => '',
            );
        $table->make_column
            ( name           => 'comment_form_note_bottom',
              type           => 'TEXT',
              default        => '',
            );
        $table->make_column
            ( name           => 'comment_form_window_height',
              type           => 'INT8',
              default        => '200',
            );
        $table->make_column
            ( name           => 'page_title_prefix',
              type           => 'VARCHAR',
              length         => 100,
              default        => '',
            );
        $table->make_column
            ( name           => 'email_notification_from_address',
              type           => 'VARCHAR',
              length         => 100,
              default        => 'noreply@socialtext.com',
            );
        $table->make_column
            ( name           => 'email_weblog_dot_address',
              type           => 'BOOLEAN',
              default        => 'f',
            );
         $table->make_column
            ( name           => 'comment_by_email',
              type           => 'BOOLEAN',
              default        => 'f',
            );
        $table->make_column
            ( name           => 'homepage_is_dashboard',
              type           => 'BOOLEAN',
              default        => 't',
            );
        $table->make_column
            ( name           => 'creation_datetime',
              type           => 'TIMESTAMPTZ',
              default        => 'CURRENT_TIMESTAMP',
              default_is_raw => 1,
            );
        $table->make_column
            ( name           => 'account_id',
              type           => 'INT8',
            );
        $table->make_column
            ( name           => 'created_by_user_id',
              type           => 'INT8',
            );
        $table->make_column
            ( name           => 'restrict_invitation_to_search',
              type           => 'BOOLEAN',
              default        => 'f',
            );
        $table->make_column
            ( name           => 'invitation_filter',
              type           => 'VARCHAR',
              length         => 100,
              nullable       => 1,
            );
        $table->make_column
            ( name           => 'invitation_template',
              type           => 'VARCHAR',
              length         => 30,
              default        => 'st',
            );
        $table->make_column
            ( name           => 'customjs_uri',
              type           => 'TEXT',
              default         => '',
            );
        $table->make_index
            ( columns  => [ $schema->table( 'Workspace' )->columns( 'name' ) ],
              unique   => 1,
              function => 'lower(name)',
            );
    }

    {
        my $table = $schema->make_table
            ( name       => 'WorkspacePingURI',
            );
        $table->make_column
            ( name           => 'workspace_id',
              type           => 'INT8',
              primary_key    => 1,
            );
        $table->make_column
            ( name           => 'uri',
              type           => 'VARCHAR',
              length         => 250,
              primary_key    => 1,
            );
    }

    {
        my $table = $schema->make_table
            ( name          => 'Watchlist',
            );
        $table->make_column
            ( name          => 'workspace_id',
              type          => 'INT8',
              primary_key   => 1,
            );
        $table->make_column
            ( name          => 'user_id',
              type          => 'INT8',
              primary_key   => 1,
            );
        $table->make_column
            ( name          => 'page_text_id',
              type          => 'VARCHAR',
              length        => 255,
              primary_key   => 1,
            );
    }

    {
        my $table = $schema->make_table
            ( name       => 'WorkspaceCommentFormCustomField',
            );
        $table->make_column
            ( name           => 'workspace_id',
              type           => 'INT8',
              primary_key    => 1,
            );
        $table->make_column
            ( name           => 'field_name',
              type           => 'VARCHAR',
              length         => 250,
              primary_key    => 1,
            );
        $table->make_column
            ( name           => 'field_order',
              type           => 'INT8',
            );
    }

    {
        my $table = $schema->make_table
            ( name       => 'Account',
            );
        $table->make_column
            ( name           => 'account_id',
              type           => 'INT8',
              sequenced      => 1,
              primary_key    => 1,
            );
        $table->make_column
            ( name           => 'name',
              type           => 'VARCHAR',
              length         => 250,
            );
        $table->make_column
            ( name           => 'is_system_created',
              type           => 'BOOLEAN',
              default        => 'f',
            );
        $table->make_index
            ( columns  => [ $schema->table( 'Account' )->columns( 'name' ) ],
              unique   => 1,
            );
    }

    {
        my $table = $schema->make_table
            ( name       => 'Permission',
            );
        $table->make_column
            ( name           => 'permission_id',
              type           => 'INTEGER',
              sequenced      => 1,
              primary_key    => 1,
            );
        $table->make_column
            ( name           => 'name',
              type           => 'VARCHAR',
              length         => 50,
            );
        $table->make_index
            ( columns  => [ $schema->table( 'Permission' )->columns( 'name' ) ],
              unique   => 1,
            );
    }

    {
        my $table = $schema->make_table
            ( name       => 'Role',
            );
        $table->make_column
            ( name           => 'role_id',
              type           => 'INTEGER',
              sequenced      => 1,
              primary_key    => 1,
            );
        $table->make_column
            ( name           => 'name',
              type           => 'VARCHAR',
              length         => 20,
            );
        $table->make_column
            ( name           => 'used_as_default',
              type           => 'BOOLEAN',
              default        => 'f',
            );
        $table->make_index
            ( columns  => [ $schema->table( 'Role' )->columns( 'name' ) ],
              unique   => 1,
            );
    }

    {
        my $table = $schema->make_table
            ( name       => 'UserWorkspaceRole',
              comment    => 'Defines a user as having a given role for a workspace.',
            );
        $table->make_column
            ( name           => 'user_id',
              type           => 'INT8',
              primary_key    => 1,
            );
        $table->make_column
            ( name           => 'workspace_id',
              type           => 'INT8',
              primary_key    => 1,
            );
        $table->make_column
            ( name           => 'role_id',
              type           => 'INTEGER',
            );
        $table->make_column
            ( name           => 'is_selected',
              type           => 'BOOLEAN',
              default        => 't',
            );
    }

    {
        my $table = $schema->make_table
            ( name       => 'WorkspaceBreadcrumb',
              comment    => 'Defines a user as having a given role for a workspace.',
            );
        $table->make_column
            ( name           => 'user_id',
              type           => 'INT8',
              primary_key    => 1,
            );
        $table->make_column
            ( name           => 'workspace_id',
              type           => 'INT8',
              primary_key    => 1,
            );
        $table->make_column
            ( name           => 'timestamp',
              type           => 'TIMESTAMPTZ',
              default        => 'CURRENT_TIMESTAMP',
              default_is_raw => 1,
            );
    }

    {
        my $table = $schema->make_table
            ( name       => 'WorkspaceRolePermission',
              comment    => 'Defines what permissions each role has for a workspace',
            );
        $table->make_column
            ( name           => 'workspace_id',
              type           => 'INT8',
              primary_key    => 1,
            );
        $table->make_column
            ( name           => 'role_id',
              type           => 'INTEGER',
              primary_key    => 1,
            );
        $table->make_column
            ( name           => 'permission_id',
              type           => 'INTEGER',
              primary_key    => 1,
            );
    }

    {
        my $table = $schema->make_table
            ( name       => 'sessions',
            );
        $table->make_column
            ( name           => 'id',
              type           => 'CHAR',
              length         => 32,
              primary_key    => 1,
            );
        $table->make_column
            ( name           => 'a_session',
              type           => 'TEXT',
            );
        $table->make_column
            ( name           => 'last_updated',
              type           => 'TIMESTAMPTZ',
            );
    }

    $schema->add_relationship
            ( columns_from => [ $schema->table( 'UserId' )->columns( 'system_unique_id' ) ],
              columns_to   => [ $schema->table( 'UserWorkspaceRole' )->columns( 'user_id' ) ],
              cardinality  => ['1', 'n'],
              from_is_dependent => 0,
              to_is_dependent   => 1,
            );
    $schema->add_relationship
            ( columns_from => [ $schema->table( 'UserId' )->columns( 'system_unique_id' ) ],
              columns_to   => [ $schema->table( 'WorkspaceBreadcrumb' )->columns( 'user_id' ) ],
              cardinality  => ['1', 'n'],
              from_is_dependent => 0,
              to_is_dependent   => 1,
            );
    $schema->add_relationship
            ( columns_from => [ $schema->table( 'UserId' )->columns( 'system_unique_id' ) ],
              columns_to   => [ $schema->table( 'UserMetadata' )->columns( 'user_id' ) ],
              cardinality  => ['1', '1'],
              from_is_dependent => 0,
              to_is_dependent   => 1,
            );
    $schema->add_relationship
            ( columns_from => [ $schema->table( 'UserId' )->columns( 'system_unique_id' ) ],
              columns_to   => [ $schema->table( 'UserEmailConfirmation' )->columns( 'user_id' ) ],
              cardinality  => ['1', '1'],
              from_is_dependent => 0,
              to_is_dependent   => 1,
            );
    $schema->add_relationship
            ( columns_from => [ $schema->table( 'UserId' )->columns( 'system_unique_id' ) ],
              columns_to   => [ $schema->table( 'Workspace' )->columns( 'created_by_user_id' ) ],
              cardinality  => ['1', 'n'],
              from_is_dependent => 0,
              to_is_dependent   => 1,
            );
            #$schema->add_relationship
            #( columns_from => [ $schema->table( 'UserId' )->columns( 'system_unique_id' ) ],
            #columns_to   => [ $schema->table( 'UserMetadata' )->columns( 'created_by_user_id' ) ],
            #cardinality  => ['1', 'n'],
            #from_is_dependent => 0,
            #to_is_dependent   => 0,
            #);
    $schema->add_relationship
            ( columns_from => [ $schema->table( 'Workspace' )->columns( 'workspace_id' ) ],
              columns_to   => [ $schema->table( 'UserWorkspaceRole' )->columns( 'workspace_id' ) ],
              cardinality  => ['1', 'n'],
              from_is_dependent => 0,
              to_is_dependent   => 1,
            );
    $schema->add_relationship
            ( columns_from => [ $schema->table( 'Workspace' )->columns( 'workspace_id' ) ],
              columns_to   => [ $schema->table( 'WorkspaceBreadcrumb' )->columns( 'workspace_id' ) ],
              cardinality  => ['1', 'n'],
              from_is_dependent => 0,
              to_is_dependent   => 1,
            );
    $schema->add_relationship
            ( columns_from => [ $schema->table( 'Workspace' )->columns( 'workspace_id' ) ],
              columns_to   => [ $schema->table( 'WorkspaceRolePermission' )->columns( 'workspace_id' ) ],
              cardinality  => ['1', 'n'],
              from_is_dependent => 0,
              to_is_dependent   => 1,
            );
    $schema->add_relationship
            ( columns_from => [ $schema->table( 'Workspace' )->columns( 'account_id' ) ],
              columns_to   => [ $schema->table( 'Account' )->columns( 'account_id' ) ],
              cardinality  => ['n', '1'],
              from_is_dependent => 1,
              to_is_dependent   => 0,
            );
    $schema->add_relationship
            ( columns_from => [ $schema->table( 'Workspace' )->columns( 'workspace_id' ) ],
              columns_to   => [ $schema->table( 'WorkspacePingURI' )->columns( 'workspace_id' ) ],
              cardinality  => ['1', 'n'],
              from_is_dependent => 0,
              to_is_dependent   => 1,
            );
    $schema->add_relationship
            ( columns_from => [ $schema->table( 'Workspace' )->columns( 'workspace_id' ) ],
              columns_to   => [ $schema->table( 'WorkspaceCommentFormCustomField' )->columns( 'workspace_id' ) ],
              cardinality  => ['1', 'n'],
              from_is_dependent => 0,
              to_is_dependent   => 1,
            );
    $schema->add_relationship
            ( columns_from => [ $schema->table( 'Permission' )->columns( 'permission_id' ) ],
              columns_to   => [ $schema->table( 'WorkspaceRolePermission' )->columns( 'permission_id' ) ],
              cardinality  => ['1', 'n'],
              from_is_dependent => 0,
              to_is_dependent   => 1,
            );
    $schema->add_relationship
            ( columns_from => [ $schema->table( 'Role' )->columns( 'role_id' ) ],
              columns_to   => [ $schema->table( 'UserWorkspaceRole' )->columns( 'role_id' ) ],
              cardinality  => ['1', 'n'],
              from_is_dependent => 0,
              to_is_dependent   => 1,
            );
    $schema->add_relationship
            ( columns_from => [ $schema->table( 'Role' )->columns( 'role_id' ) ],
              columns_to   => [ $schema->table( 'WorkspaceRolePermission' )->columns( 'role_id' ) ],
              cardinality  => ['1', 'n'],
              from_is_dependent => 0,
              to_is_dependent   => 1,
            );
    $schema->add_relationship
            ( columns_from  => [
                $schema->table( 'UserId' )->columns( 'system_unique_id' ) ],
              columns_to    => [
                $schema->table( 'Watchlist' )->columns('user_id') ],
              cardinality   => ['1', 'n'],
              from_is_dependent => 0,
              to_is_dependent   => 1,
            );
    $schema->add_relationship
            ( columns_from => [
                  $schema->table('Workspace')->columns('workspace_id') ],
              columns_to => [
                  $schema->table('Watchlist')->columns('workspace_id') ],
              cardinality       => [ '1', 'n' ],
              from_is_dependent => 0,
              to_is_dependent   => 1,
            );

    return $schema;
}

1;

__END__

=head1 NAME

Socialtext::Schema - Loads an Alzabo::Runtime::Schema object and connects it to the DBMS

=head1 SYNOPSIS

  use Socialtext::Schema;

  my $schema = Socialtext::Schema->Load();

  Socialtext::Schema->CheckDBH();

=head1 DESCRIPTION

This module provides some methods to load the Alzabo schema object and
make sure it is connected to the DBMS. If a class which uses the
schema tries to perform an operation that requires a DBMS connection,
it will transparently connect to the DBMS if necessary.

=head1 METHODS

This module provides the following methods:

=over 4

=item Load()

This retrieves the current C<Alzabo::Runtime::Schema> object. The
returned schema may not be connected to the DBMS.

=item LoadAndConnect()

This retrieves the current C<Alzabo::Runtime::Schema> object and makes
sure it is connected to the DBMS before returning it.

=item CheckDBH()

This ensure that the schema object is connected the DBMS. Calling this
causes a query, so it should not be called too often. Under mod_perl,
calling it once per request is a good way to ensure that the database
connection has not gone stale. Outside of a persistent process, there
is no need to call this, just call C<LoadAndConnect()> to get a schema
object with a valid database connection.

=item SchemaObject()

Returns a C<Alzabo::Create::Schema> object for the schema. Use this to
generate DDL SQL.

=back

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2006 Socialtext, Inc., All Rights Reserved.

=cut
