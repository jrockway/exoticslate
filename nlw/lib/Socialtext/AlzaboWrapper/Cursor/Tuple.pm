# @COPYRIGHT@
package Socialtext::AlzaboWrapper::Cursor::Tuple;
use strict;
use warnings;

use base 'Class::AlzaboWrapper::Cursor';

sub new {
    my $class = shift;
    my %p = @_;

    my $self = $class->SUPER::new(%p);

    $self->{columns} = $p{columns};

    return $self;
}

sub _new_from_row
{
    my $self = shift;
    my $row = shift;

    return undef unless defined $row;
    return $row->select($self->{columns});
}

1;
