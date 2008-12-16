# @COPYRIGHT@
package Socialtext::SQL;
use strict;
use Socialtext::AppConfig;
use Socialtext::Timer;
use DateTime::Format::Pg;
use DBI;
use base 'Exporter';
use Carp qw/croak cluck/;

=head1 NAME

Socialtext::SQL - wrapper interface around SQL methods

=head1 SYNOPSIS

  use Socialtext::SQL qw/sql_execute sql_begin_work sql_commit sql_rollback/;

  # Regular, auto-commit style:
  my $sth = sql_execute( $SQL, @BIND );
   
  # DIY commit:
  sql_begin_work();
  eval { sql_execute( $SQL, @BIND ) };
  if ($@) {
      sql_roll_back();
  }
  else {
      sql_commit();
  }

=head1 DESCRIPTION

Provides methods with extra error checking and connections to the database.

=head1 METHODS

=cut

our @EXPORT_OK = qw(
    get_dbh disconnect_dbh
    sql_execute sql_selectrow sql_singlevalue 
    sql_commit sql_begin_work sql_rollback sql_in_transaction
    sql_convert_to_boolean sql_convert_from_boolean
    sql_parse_timestamptz sql_format_timestamptz
);
our %EXPORT_TAGS = (
    'exec' => [qw(sql_execute sql_selectrow sql_singlevalue)],
    'time' => [qw(sql_parse_timestamptz sql_format_timestamptz)],
    'bool' => [qw(sql_convert_to_boolean sql_convert_from_boolean)],
    'txn'  => [qw(sql_commit sql_begin_work
                  sql_rollback sql_in_transaction)],
);


our $DEBUG = 0;
our $TRACE_SQL = 0;
our $PROFILE_SQL = 0;
our %DBH;
our $Level = 0;

=head2 get_dbh()

Returns a handle to the database.

=cut

sub get_dbh {
    Socialtext::Timer->Continue('get_dbh');
    if ($DBH{handle} and $DBH{handle}->ping) {
        warn "Returning existing handle $DBH{handle}" if $DEBUG;
        Socialtext::Timer->Pause('get_dbh');
        return $DBH{handle} 
    }
    cluck "Creating a new DBH" if $DEBUG;
    my %params = Socialtext::AppConfig->db_connect_params();
    my $dsn = "dbi:Pg:database=$params{db_name}";

    $DBH{handle} = DBI->connect($dsn, $params{user}, "",  {
            AutoCommit => 0,
            pg_enable_utf8 => 1,
        }) or croak "Could not connect to database with dsn: $dsn: $!";
    $DBH{st_in_transaction} = 0;
    Socialtext::Timer->Pause('get_dbh');
    return $DBH{handle};
}

=head2 disconnect_dbh

Forces the DBH to disconnect.  Useful for scripts to avoid deadlocks.

=cut

sub disconnect_dbh {
    if ($DBH{handle}) {
        $DBH{handle}->disconnect;
        %DBH = ();
    }
}


=head2 sql_execute( $SQL, @BIND )

sql_execute() will wrap the execution in a begin/commit block
UNLESS the caller has already set up a transaction

Returns a statement handle.

=cut

sub sql_execute {
    my $statement = shift;
    # rest of @_ are bindings, prevent making copies

    my $dbh = get_dbh();
    Socialtext::Timer->Continue('sql_execute');

    my $in_tx = sql_in_transaction();
    warn "In transaction at start of sql_execute() - $in_tx" 
        if $in_tx and $DEBUG;

    my ($sth, $rv);
    if ($DEBUG or $TRACE_SQL) {
        my (undef, $file, $line) = caller($Level);
        warn "Preparing ($statement) "
            . _list_bindings(\@_)
            . " from $file line $line\n";
    }
    if ($PROFILE_SQL) {
        my (undef, $file, $line) = caller($Level);
        warn "Profiling ($statement) "
            . _list_bindings(\@_)
            . " from $file line $line\n";
        my $explain = "EXPLAIN ANALYZE $statement";
        my $esth = $dbh->prepare($explain);
        $esth->execute(@_);
        my $lines = $esth->fetchall_arrayref();
        warn map { "$_->[0]\n" } @$lines;
    }
    eval {
        Socialtext::Timer->Continue('sql_prepare');
        $sth = $dbh->prepare($statement);
        Socialtext::Timer->Pause('sql_prepare');
        $sth->execute(@_) ||
            die "execute failed: " . $sth->errstr;
    };
    if (my $err = $@) {
        my $msg = "Error during sql_execute():\n$statement\n";
        $msg .= _list_bindings(\@_);
        unless ($in_tx) {
            warn "Rolling back in sql_execute()" if $DEBUG;
            sql_rollback();
        }
        Socialtext::Timer->Pause('sql_execute');
        croak "${msg}Error: $err";
    }

    # Unless the caller has explicitly specified a transaction via
    # sql_begin_work(), we will commit each chunk.
    # If the caller is using a transaction, they are responsible for
    # committing or rolling back
    unless ($in_tx) {
        warn "Committing in sql_execute()" if $DEBUG;
        sql_commit();
    }

    Socialtext::Timer->Pause('sql_execute');
    return $sth;
}

sub _list_bindings {
    my $bindings = shift;
    return 'bindings=('
         . join(',', map { defined $_ ? "'$_'" : 'NULL' } @$bindings)
         . ')';
}

=head2 sql_selectrow( $SQL, @BIND )

Wrapper around $sth->selectrow_array 

=cut

sub sql_selectrow {
    my ( $statement, @bindings ) = @_;

    Socialtext::Timer->Continue('sql_selectrow');
    my @result = get_dbh->selectrow_array($statement, undef, @bindings);
    Socialtext::Timer->Pause('sql_selectrow');
    return @result;
}

=head2 sql_singlevalue( $SQL, @BIND )

Wrapper around returning a single value from a query.

=cut

sub sql_singlevalue {
    my ( $statement, @bindings ) = @_;

    local $Level = $Level + 1;
    my $sth = sql_execute($statement, @bindings);
    my $value;
    $sth->bind_columns(undef, \$value);
    $sth->fetch();
    $sth->finish();
    $value =~ s/\s+$// if defined $value;
    return $value;
}

=head2 sql_in_transaction()

Returns true if we currently in a transaction

=head2 sql_begin_work()

Starts a transaction, so sql_execute will not auto-commit.

=head2 sql_commit()

Commit a transaction started by the calling code.

=head2 sql_rollback()

Rollback a transaction started by the calling code.

=cut

# Only allow 1 transaction at a time, ignore nested transactions.  This
# may or may not be a good strategy.  Ponder.
{
    sub sql_in_transaction { 
        return $DBH{st_in_transaction};
    }

    sub sql_begin_work {
        if ($DBH{st_in_transaction}) {
            croak "Already in a transaction!";
        }
        warn "Beginning transaction" if $DEBUG;
        $DBH{st_in_transaction}++;
    }
    sub sql_commit {
        my $dbh = get_dbh();
        $DBH{st_in_transaction}-- if $DBH{st_in_transaction};
        warn "Committing transaction" if $DEBUG;
        return $dbh->commit()
    }
    sub sql_rollback {
        my $dbh = get_dbh();
        $DBH{st_in_transaction}-- if $DBH{st_in_transaction};
        warn "Rolling back transaction" if $DEBUG;
        return $dbh->rollback()
    }
}

=head2 sql_convert_to_boolean()

Perl true-false to sql boolean.

=cut

sub sql_convert_to_boolean {
    my $value= shift;
    my $default = shift;

    return $default if (!defined($value));
    return $value ? 't' : 'f';
}

=head2 sql_convert_from_boolean()

Maps SQL t/f to perl true-false.

=cut

sub sql_convert_from_boolean {
    my $value= shift;

    return $value eq 't' ? 1 : 0;
}

=head2 sql_parse_timestamptz()

Parses a timestamptz column into a DateTime object (technically it's a
DateTime::Format::Pg)

=cut

sub sql_parse_timestamptz {
    my $value = shift;
    return DateTime::Format::Pg->parse_timestamptz($value);
}

=head2 sql_format_timestamptz()

Converts a DateTime object into a timestamptz column format.

=cut

sub sql_format_timestamptz {
    my $dt = shift;
    my $fmt = DateTime::Format::Pg->format_timestamptz($dt);
    if (!$dt->is_finite) {
        # work around a DateTime::Format::Pg bug
        $fmt =~ s/infinite$/infinity/g;
    }
    return $fmt;
}

1;
