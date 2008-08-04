#@COPYRIGHT@
package Socialtext::SQL;
use strict;
use warnings;
use Test::More;
use base 'Exporter';
use unmocked 'Data::Dumper';

our @EXPORT_OK = qw/sql_execute sql_ok sql_selectrow sql_singlevalue get_dbh
                    sql_in_transaction sql_begin_work sql_commit sql_rollback/;
our @SQL;
our @RETURN_VALUES;

sub sql_execute {
    push @SQL, { sql => shift, args => [@_] };
    
    my $sth_args = shift @RETURN_VALUES;
    return mock_sth->new(%{ $sth_args || {} });
}

sub get_dbh { }
sub sql_in_transaction { 0 }
sub sql_begin_work { }
sub sql_commit { }
sub sql_rollback { }
sub sql_selectrow { sql_execute(@_) };
sub sql_singlevalue { sql_execute(@_) };

sub sql_ok {
    my %p = @_;

    # Booya - stash rocks - show test failures in the right file.
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $sql = shift @SQL;
    $p{name} = $p{name} ? "$p{name} " : '';
    my $expected_sql = $p{sql};
    if ($expected_sql) {
        my $observed_sql = _normalize_sql($sql->{sql});
        if (ref($p{sql})) {
            like $observed_sql, $expected_sql, 
                 $p{name} . 'SQL matches';
        }
        else {
            is $observed_sql, _normalize_sql($expected_sql), 
               $p{name} . 'SQL matches exactly';
        }
    }

    if ($p{args}) {
        is_deeply $sql->{args}, $p{args}, $p{name} . 'SQL args match'
            or warn Dumper($sql->{args});
    }
}

sub _normalize_sql {
    my $sql = shift;
    $sql =~ s/\s+/ /sg;
    $sql =~ s/\s*$//;
    return $sql;
}

package mock_sth;
use strict;
use warnings;
use base 'Socialtext::MockBase';

sub finish {}

sub fetchall_arrayref {
    my $self = shift;
    return $self->{return} || [];
}

sub fetchrow_arrayref {
    my $self = shift;
    return shift @{ $self->{return} };
}

sub fetchrow_hashref {
    my $self = shift;
    return shift @{ $self->{return} };
}

1;
