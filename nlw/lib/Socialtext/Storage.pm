package Socialtext::Storage;
# @COPYRIGHT@
use strict;
use warnings;

use Carp qw(croak);

sub new {
    my ($class, $id, $user_id) = @_;
    croak "id required" unless $id;
    my $self = {
        id => $id,
        user_id => $user_id || 0,
    };
    bless $self, $class;
    $self->load_data;
    return $self;
}

sub classes {
    my $self = shift;
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
