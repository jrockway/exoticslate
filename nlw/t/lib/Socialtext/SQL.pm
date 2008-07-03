#@COPYRIGHT@
package Socialtext::SQL;
use strict;
use warnings;
use Test::More;
use base 'Exporter';
our @EXPORT_OK = qw/sql_execute sql_ok sql_selectrow sql_singlevalue get_dbh/;

our @SQL;
our @RETURN_VALUES;

sub sql_execute {
    push @SQL, { sql => shift, args => [@_] };
    
    my $sth_args = shift @RETURN_VALUES;
    return mock_sth->new(%{ $sth_args || {} });
}

sub get_dbh { }
sub sql_selectrow { sql_execute(@_) };
sub sql_singlevalue { sql_execute(@_) };

sub sql_ok {
    my %p = @_;

    # Booya - stash rocks - show test failures in the right file.
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $sql = shift @SQL;
    $p{name} = $p{name} ? "$p{name} " : '';
    if ($p{sql}) {
        $sql->{sql} =~ s/\s+/ /sg;
        $sql->{sql} =~ s/\s*$//;
        if (ref($p{sql})) {
            like $sql->{sql}, $p{sql}, $p{name} . 'SQL matches';
        }
        else {
            is $sql->{sql}, $p{sql}, $p{name} . 'SQL matches exactly';
        }
    }

    if ($p{args}) {
        is_deeply $sql->{args}, $p{args}, $p{name} . 'SQL args match';
    }
}

package mock_sth;
use strict;
use warnings;
use base 'Socialtext::MockBase';

sub fetchall_arrayref {
    my $self = shift;
    return $self->{return} || [];
}

1;
