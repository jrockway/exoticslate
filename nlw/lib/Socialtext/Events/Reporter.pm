package Socialtext::Events::Reporter;
# @COPYRIGHT@
use warnings;
use strict;
use Socialtext::SQL qw/sql_execute/;

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    return bless {}, $class;
}

sub get_events {
    my $self = shift;
    my %opts = @_;

    my $sth = sql_execute(<<EOSQL);
SELECT * FROM event
EOSQL
    return $sth->fetchall_arrayref;
}

1;
