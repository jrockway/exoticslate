#@COPYRIGHT@
package Socialtext::SQL;
use strict;
use warnings;
use base 'Exporter';
our @EXPORT_OK = qw/Reset_mock_sql sql_execute/;

our @SQL;
our @RETURN_VALUES;

sub sql_execute {
    push @SQL, { sql => shift, args => [@_] };
    
    my $sth_args = shift @RETURN_VALUES;
    return mock_sth->new(%{ $sth_args || {} });
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
