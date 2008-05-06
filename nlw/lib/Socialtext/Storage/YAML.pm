package Socialtext::Storage::YAML;
# @COPYRIGHT@
use strict;
use base 'Socialtext::Storage';

use Socialtext::Paths;
use File::Path qw(mkpath);
use YAML;

# This will be replaced by the database
my $root = Socialtext::Paths::storage_directory('stored');

sub load_data {
    my $self = shift;
    mkpath $root unless -d $root;
    $self->{file} ||= "$root/$self->{id}.yaml";
    if (-f $self->{file}) {
        $self->{yaml} = YAML::LoadFile($self->{file});
    }
}

sub get {
    my ($self,$key) = @_;
    return $self->{yaml}{$key};
}

sub set {
    my ($self,$key,$val) = @_;
    $self->{yaml}{$key} = $val;
    $self->_save;
}

sub delete {
    my ($self, $key) = @_;
    delete $self->{yaml}{$key};
    $self->_save;
}

sub _save {
    my $self = shift;
    die "No filename!" unless $self->{file};
    YAML::DumpFile($self->{file}, $self->{yaml});
}

sub purge {
    my $self = shift;
    $self->{yaml} = undef;
    $self->_save;
}

sub exists {
    my ($self,$key) = @_;
    return exists $self->{yaml}{$key};
}

sub remove {
    my $self = shift;
    $self->purge;
    unlink $self->{file}
        or die "Couldn't unlink $self->{file}: $!";
}

sub keys {
    my $self = shift;
    return unless $self->{yaml};
    return CORE::keys %{$self->{yaml}};
}

1;
