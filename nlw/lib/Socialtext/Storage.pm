package Socialtext::Storage;
# @COPYRIGHT@
use strict;
use warnings;

use Carp qw(croak);

sub new {
    my ($class, $id) = @_;
    croak "id required" unless $id;
    my $self = { id => $id };
    bless $self, $class;
    $self->load_data;
    return $self;
}

sub load_data {
    die "Sub must be overridden";
}

sub get {
    my ($self,$key) = @_;
    die "Sub must be overridden";
}

sub set {
    my ($self,$key,$val) = @_;
    die "Sub must be overridden";
}

sub purge {
    my $self = shift;
    die "Sub must be overridden";
}

sub remove {
    my $self = shift;
    die "Sub must be overridden";
}

sub keys {
    my $self = shift;
    die "Sub must be overridden";
}

1;
