package Socialtext::Storage::YAML;
# @COPYRIGHT@
use strict;
use base 'Socialtext::Storage';

use Socialtext::Paths;
use File::Path qw(mkpath);
use YAML;
use Carp qw(croak);

# This will be replaced by the database
my $root = Socialtext::Paths::storage_directory('stored');

sub new {
    my ($class, $id) = @_;
    croak "id required" unless $id;
    my $self = {
        file => "$root/$id.yaml"
    };
    mkpath $root unless -d $root;
    bless $self, $class;
    if (-f $self->{file}) {
        $self->{yaml} = YAML::LoadFile($self->{file});
    }
    return $self;
}

sub get {
    my ($self,$key) = @_;
    return $self->{yaml}{$key};
}

sub set {
    my ($self,$key,$val) = @_;
    $self->{yaml}{$key} = $val;
}

sub save {
    my $self = shift;
    die "No filename!" unless $self->{file};
    YAML::DumpFile($self->{file}, $self->{yaml});
}

sub purge {
    my $self = shift;
    $self->{yaml} = undef;
    $self->save;
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
