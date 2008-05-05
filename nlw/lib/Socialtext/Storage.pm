package Socialtext::Storage;
# @COPYRIGHT@
use strict;
use warnings;

sub get {
    my ($self,$key) = @_;
    die "Sub must be overridden";
}

sub set {
    my ($self,$key,$val) = @_;
    die "Sub must be overridden";
}

sub save {
    my $self = shift;
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
