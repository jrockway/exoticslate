# @COPYRIGHT@
package Socialtext::SQL;

use base 'Exporter';

our @EXPORT_OK = qw( sql_execute sql_selectrow );

use Carp 'carp';
use DBI;
use Socialtext::Schema;

sub _dbh() { Socialtext::Schema::LoadAndConnect->driver->handle }

sub sql_execute {
    my ( $statement, @bindings ) = @_;

    my $sth = _dbh->prepare($statement);
    $sth->execute(@bindings) || die; # FIXME: exception
    return $sth;
}

# XXX: Rename as sql_selectrow_array? -mml
sub sql_selectrow {
    my ( $statement, @bindings ) = @_;

    return _dbh->selectrow_array($statement, undef, @bindings);
}

1;
