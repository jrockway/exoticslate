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

=head2 get_events()

Return an arrayref of events matching the specified criteria.

Parameters:

=over 4

=item before - Any events from before this timestamp

=item after - Any events from after this timestamp

=item action - Any events matching this action

=item limit - Return this number of events at most

=back

=cut

sub get_events {
    my $self = shift;
    my %opts = @_;

    my @args;
    my $where = '';
    if (my $b = $opts{before}) {
        $where = q{WHERE timestamp < '?'::timestamptz};
        push @args, $b;
    }
    elsif (my $a = $opts{after}) {
        $where = q{WHERE timestamp > '?'::timestamptz};
        push @args, $a;
    }
    if (my $a = $opts{action}) {
        $where .= $where ? ' AND ' : 'WHERE ';
        $where .= 'action = ?';
        push @args, $a;
    }

    my $limit = '';
    if (my $l = $opts{limit} || $opts{count}) {
        $limit = 'LIMIT ?';
        push @args, $l;
    }

    my $sth = sql_execute(<<EOSQL, @args);
SELECT * FROM event
    $where
    $limit
EOSQL
    return $sth->fetchall_arrayref;
}

1;
