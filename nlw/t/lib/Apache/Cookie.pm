package Apache::Cookie;
# @COPYRIGHT@
use strict;
use warnings;

our $DATA = {};

sub new {
    my ($class, %opts) = @_;
    my $self = { %opts };
    bless $self, $class;
}

sub value {
    my $self = shift;
    return %{ $self->{value} };
}

sub fetch {
    return $DATA;
}

1;
