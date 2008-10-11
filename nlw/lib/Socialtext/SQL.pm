# @COPYRIGHT@
package Socialtext::SQL;
use strict;
use Socialtext::AppConfig;
use Socialtext::Timer;
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
    sql_execute sql_selectrow sql_commit sql_begin_work
    sql_singlevalue sql_rollback sql_in_transaction
    sql_convert_to_boolean sql_convert_from_boolean
    get_dbh disconnect_dbh
);


our $DEBUG = 0;
our $TRACE_SQL = 0;
our %DBH;

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
        }) or die "Could not connect to database with dsn: $dsn: $!";
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
    my ( $statement, @bindings ) = @_;
    my $dbh = get_dbh();
    Socialtext::Timer->Continue('sql_execute');

    my $in_tx = sql_in_transaction();
    warn "In transaction at start of sql_execute() - $in_tx" 
        if $in_tx and $DEBUG;

    my ($sth, $rv);
    if ($DEBUG or $TRACE_SQL) {
        my (undef, $file, $line) = caller;
        warn "Preparing ($statement) "
            . _list_bindings(\@bindings)
            . " from $file line $line\n";
    }
    eval {
        Socialtext::Timer->Continue('sql_prepare');
        $sth = $dbh->prepare($statement);
        Socialtext::Timer->Pause('sql_prepare');
        $sth->execute(@bindings) ||
            die "execute failed: " . $sth->errstr;
    };
    if (my $err = $@) {
        my $msg = "Error during sql_execute():\n$statement\n";
        if (@bindings) {
            local $" = ',';
            $msg .= "Bindings: ("
                  . join(', ', map { defined $_ ? $_ : 'undef' } @bindings)
                  . ")\n";
        }
        unless ($in_tx) {
            warn "Rolling back in sql_execute()" if $DEBUG;
            sql_rollback();
        }
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
         . join(',', map { defined $_ ? $_ : 'NULL' } @{$bindings})
         . ')';
}

=head2 sql_selectrow( $SQL, @BIND )

Wrapper around $sth->selectrow_array 

=cut

sub sql_selectrow {
    my ( $statement, @bindings ) = @_;

    return get_dbh->selectrow_array($statement, undef, @bindings);
}

=head2 sql_singlevalue( $SQL, @BIND )

Wrapper around returning a single value from a query.

=cut

sub sql_singlevalue {
    my ( $statement, @bindings ) = @_;

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

=head2 sql_commit()()

Commit a transaction started by the calling code.

=head2 sql_rollback()()

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

1;
