package Socialtext::Storage;
use strict;
use warnings;

our %DATA;

sub new {
    my ($class, $id) = @_;
    return bless { id => $id }, $class;
}

sub id { $_[0]{id} }

sub preload {}

sub Search {
    my ($class, %terms) = @_;
    my ($id) = grep {
        my $s_id = $_;
        keys %terms == grep {
            exists $DATA{$s_id}{$_} and $DATA{$s_id}{$_} eq $terms{$_}
        } keys %terms
    } keys %DATA;
    return $class->new($id) if $id;
}

sub exists {
    my ($self, $key) = @_;
    return exists $DATA{$self->{id}}{$key};
}

sub get {
    my ($self, $key) = @_;
    return $DATA{$self->{id}}{$key};
}

sub set {
    my ($self, $key, $value) = @_;
    return $DATA{$self->{id}}{$key} = $value;
}

sub remove {
    my ($self) = @_;
    $DATA{$self->{id}} = {};
}

sub purge { $_[0]->remove }

sub _data {
    my $self = shift;
    return $DATA{$self->{id}};
}

sub keys {
    my ($self) = @_;
    return keys %{ $DATA{$self->{id}} };
}

1;
