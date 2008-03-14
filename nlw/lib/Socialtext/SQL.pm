# @COPYRIGHT@
package Socialtext::SQL;
use Socialtext::Schema;
use DBI;
use base 'Exporter';

our @EXPORT_OK = qw(
    sql_execute sql_selectrow sql_commit sql_begin_work
    sql_singlevalue sql_rollback sql_in_transaction
    sql_convert_to_boolean sql_convert_from_boolean
);

sub _dbh() { Socialtext::Schema::LoadAndConnect->driver->handle }

sub sql_execute {
    my ( $statement, @bindings ) = @_;

    my ($sth, $rv);
    eval {
        $sth = _dbh->prepare($statement);
        $sth->execute(@bindings) ||
            die "Error during execute - bindings=("
                . join(', ', @bindings) . ')';
    };
    if ($@) {
        my $msg = "Error during sql_execute:\n$statement\n";
        if (@bindings) {
            local $" = ',';
            $msg .= "Bindings: ("
                  . join(', ', map { defined $_ ? $_ : 'undef' } @bindings)
                  . ")\n";
        }
        die "${msg}Error: $@";
    }
    return $sth;
}

sub sql_selectrow {
    my ( $statement, @bindings ) = @_;

    return _dbh->selectrow_array($statement, undef, @bindings);
}

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

# Only allow 1 transaction at a time, ignore nested transactions.  This
# may or may not be a good strategy.  Ponder.
{
    my $In_transaction = 0;
    sub sql_in_transaction { $In_transaction }

    sub sql_begin_work {
        return if $In_transaction;
        eval { _dbh->begin_work() or die _dbh->errstr; };
        if ($@) {
            die $@ unless ($@ =~ /Already in a transaction/);
        }
        return $In_transaction++;
    }
    sub sql_commit {
        $In_transaction = 0;
        return _dbh->commit()
    }
    sub sql_rollback {
        $In_transaction = 0;
        return _dbh->rollback()
    }
}

sub sql_convert_to_boolean {
    my $value= shift;
    my $default = shift;

    return $default if (!defined($value));
    return $value ? 't' : 'f';
}

sub sql_convert_from_boolean {
    my $value= shift;

    return $value eq 't' ? 1 : 0;
}

1;
