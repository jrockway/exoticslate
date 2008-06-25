# @COPYRIGHT@
package Socialtext::Schema;
use strict;
use warnings;
use File::Spec;
use Socialtext::Paths;
use Socialtext::AppConfig;
use Socialtext::System qw/shell_run/;
use Socialtext::SQL qw/sql_singlevalue sql_execute sql_begin_work 
                       sql_commit sql_rollback disconnect_dbh/;

=head1 NAME

Socialtext::Schema - management of the database Schema

=head1 SYNOPSIS

  use Socialtext::Schema;

  Socialtext::Schema->new->sync();

=head1 DESCRIPTION

This class provides the behaviour to create, dump and upgrade the database
schema.  The schema is upgraded through a series of SQL patch files.

=head1 Package Methods

=head2 schema_dir()

Returns the directory schemas should be found in.

=cut

sub schema_dir {
    return $ENV{ST_SCHEMA_DIR} || File::Spec->catfile(
        Socialtext::AppConfig->config_dir(), 'db',
    );
}

=head1 Methods

=head2 new()

Create a new schema object.  Doesn't need any parameters.

=cut

sub new {
    my $class = shift;
    my $self = {
        @_,
    };
    bless $self, $class;
    return $self;
}

=head2 schema_name()

Returns the name of the schema to modify.

=cut

sub schema_name {
    my $self = shift;
    my %params = $self->connect_params();
    return $self->{schema_name} || $params{schema_name};
}

=head2 connect_params()

Returns a hash of the parameters to connect to the specified schema.

=cut

sub connect_params {
    my %params = Socialtext::AppConfig->db_connect_params();
    $params{psql} = "psql -U $params{user} $params{db_name}";
    return %params;
}

=head2 recreate()

Dumps, drops, and then re-creates the schema.

Optionally, you may pass in a list of key-value pairs as options.

=head3 recreate() options:

=over 4

=item no_dump

Don't do a database dump before dropping.  Useful for testing.

=back

=cut

sub recreate {
    my $self = shift;
    my %opts = @_;

    eval { $self->dump } unless $opts{no_dump};
    $self->dropdb;
    $self->createdb;
    $self->run_sql_file($self->_schema_filename);
    $self->_add_required_data;
}

=head2 sync()

Create or update the schema to the latest version.

=cut

sub sync {
    my $self = shift;

    eval { $self->createdb };
    my $current_version = $self->current_version;
    $self->_display("Current schema version is $current_version\n");
    if ($current_version == 0) {
        $self->run_sql_file($self->_schema_filename);
        $self->_add_required_data;
        $self->_display("Set up fresh schema\n");
    }
    else {
        my @scripts = $self->_update_scripts_from($current_version);
        if (@scripts) {
            eval { $self->dump };
    
            for my $s (@scripts) {
                $self->run_sql_file($s->{name});
                $self->set_schema_version($s->{to});
            }
        }
        else {
            $self->_display("No updates necessary.\n");
            return;
        }

        print "\n";
        # Double check that we're up-to-date
        my $old_version = $current_version;
        $current_version = $self->current_version;
        if ($old_version == $current_version) {
            $self->_display("No updates were successfully applied.\n");
            return;
        }

        my $up_msg = "Updated from $old_version to $current_version.";
        if ($self->_update_scripts_from($current_version)) {
            $self->_display("Not all updates applied.  $up_msg\n");
            return;
        }
        $self->_display("$up_msg  Schema is up-to-date.\n");
    }
}

sub _add_required_data {
    my $self = shift;
    return unless $self->schema_name eq 'socialtext';
    require Socialtext::Data;

    for my $c ( Socialtext::Data::Classes() ) {
        eval "require $c";
        die $@ if $@;

        if ($c->can('EnsureRequiredDataIsPresent')) {
            $self->_display("Adding required data for $c\n") 
                if $self->{verbose};
            $c->EnsureRequiredDataIsPresent;
        }
    }
}

sub _update_scripts_from {
    my $self = shift;
    my $from_version = shift;

    my $schema_dir = $self->schema_dir;
    my $schema_name = $self->schema_name;
    my @all_scripts = 
        map { $_->{name} }
        sort { $a->{from} <=> $b->{from} }
        map { m/-(\d+)-to-\d+\.sql/; { name => $_, from => $1 } }
        glob("$schema_dir/$schema_name-*-to-*.sql");


    my @to_run;
    for my $s (@all_scripts) {
        next unless $s =~ m#/$schema_name-(\d+)-to-(\d+)\.sql$#;
        my ($s_from, $s_to) = ($1, $2);
        next if $s_from < $from_version;
        push @to_run, {
            name => $s,
            from => $s_from,
            to => $s_to,
        };
    }
    return @to_run;
}

=head2 version()

Prints out the current schema version.

=cut

sub version {
    my $self = shift;
    my $version = $self->current_version;
    my $schema = $self->schema_name;
    $self->_display("Schema $schema version: $version\n");
}

=head2 current_version()

Returns the version of the schema currently used by the database.

=cut

# If the "System" table exists, read the version out of that for our schema.
# Otherwise: if a certain table exists, assume it is version 1
# Otherwise: assume it is a fresh database, and return version 0
sub current_version {
    my $self = shift;
    my %c = $self->connect_params();

    my $version = 0;
    my $schema_field = $self->schema_name . '-schema-version';
    eval {
        $version = sql_singlevalue(<<EOT, $schema_field);
SELECT value FROM "System"
    WHERE field = ?
EOT
    };
    eval { sql_rollback() };
    return $version if $version;

    # If we couldn't find a version, check for a given SQL returning something
    # to determine if this is a fresh database, or just one without a version
    # yet.  The SQL we run is dependent on the schema being used.
    # Subclasses of this class can provide their own check method
    return 0 if $self->_is_fresh_database;
    return 1;
}

# This method allows us to do special things when migrating from systems
# before this module was refactored.
sub _is_fresh_database {
    my $self = shift;
    my $name = $self->schema_name;

    if ($name eq 'socialtext') {
        eval {
            sql_execute(q{SELECT account_id FROM "Account" LIMIT 1});
        };
        return 0 if !$@;
    }
    return 1;
}

=head2 dump()

Dumps out the database to a sql dump file.

=cut

sub dump {
    my $self    = shift;
    my %c = $self->connect_params();
    my $time    = time;
    my $dir     = Socialtext::Paths::storage_directory("db-backups");
    my $file    = Socialtext::File::catfile($dir, "$c{db_name}-dump.$time.sql");

    my @parms = (
        'pg_dump',
        '-C',
        '-D',
        '-U' => $c{user},
        '-f' => $file,
    );
    push( @parms, '--password' => $c{password} )  if $c{password};
    push( @parms, '--host'     => $c{host} )      if $c{host};
    push( @parms, $c{db_name} );

    $self->_db_shell_run( join ' ', @parms );
    $self->_display("Dumped data to $file\n");
}

sub _display {
    my $self = shift;
    my $msg = shift;

    print $self->schema_name . ": $msg";
}

=head2 run_sql_file 

Executes the SQL file with psql.

=cut

sub run_sql_file {
    my $self = shift;
    my $file = shift;

    my %c = $self->connect_params();
    $self->_db_shell_run("$c{psql} -e -f $file");
}

=head2 set_schema_version 

Sets the schema version to the given value in the "System" table.

=cut

sub set_schema_version {
    my $self = shift;
    my $new_version = shift;

    # ideally, this would happen in the same transaction as the SQL patch
    my $schema_field = $self->schema_name . '-schema-version';
    sql_begin_work();
    sql_execute('DELETE FROM "System" WHERE field = ?', $schema_field);
    sql_execute('INSERT INTO "System" VALUES (?,?)', 
        $schema_field, $new_version);
    sql_commit();
}


sub _schema_filename {
    my $self = shift;
    my $schema_file = File::Spec->catfile(
        schema_dir(), $self->schema_name . '-schema.sql',
    );
    return $schema_file;
}

=head2 createdb 

Creates the database for the schema to live in.

=cut

sub createdb {
    my $self = shift;
    my %c = $self->connect_params();
    disconnect_dbh();
    $self->_db_shell_run("createdb $c{db_name}");
    $self->_db_shell_run("sudo -u postgres psql $c{db_name} -c 'CREATE LANGUAGE plpgsql'");
}

=head2 dropdb 

Removes the current database, without dumping it.

=cut

sub dropdb {
    my $self = shift;
    my %c = $self->connect_params();
    disconnect_dbh();
    sleep 2;
    eval {
        $self->_db_shell_run("dropdb $c{db_name}");
    };
    warn "Error dropping: $@" if $@;
}

sub _log_file { Socialtext::Paths::log_directory() . '/st-db.log' }

sub _db_shell_run {
    my $self = shift;
    my $command = shift;
    my $log_file = _log_file();
    local $Socialtext::System::SILENT_RUN = !$self->{verbose};
    shell_run($command . " >> $log_file 2>&1");
}

1;

__END__

=head1 NAME

Socialtext::Schema - management of the database Schema

=head1 SYNOPSIS

  use Socialtext::Schema;

  # From command line:
  Socialtext::Schema::Run();

  # Recreate the database
  Socialtext::Schema->new->recreate();

=head1 DESCRIPTION

This class provides the behaviour to create, dump and upgrade the database
schema.  The schema is upgraded through a series of SQL patch files.

=cut

