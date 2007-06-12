# @COPYRIGHT@
package Socialtext::MultiPlugin;
use strict;
use warnings;

use base 'Socialtext::Base';

sub _realize {
    # Return the subclass if it can perform the requested method
    my $class = shift;
    my $driver = shift;
    my $method = shift;
    my $real_class = $class->base_package() . "::" . $driver;
    eval "require $real_class";
    die "Couldn't load $real_class: $@" if $@;

    if ( $real_class->can($method) ) {
        return $real_class;
    }

    return undef;
}

sub _first {
    my $self = shift;
    my $method = shift;
    for my $driver ($self->_drivers) {
        my $subclass = $self->_realize($driver, $method);
        if ($subclass) {
            my $res = $subclass->$method(@_);
            return $res if $res;
        }
    }
    return undef;
}

sub _aggregate {
    my $self = shift;
    my $method = shift;
    my @collection;
    for my $driver ($self->_drivers) {
        push @collection, $self->_realize($driver, $method)->$method(@_);
    }
    return @collection;
}

1;
