package Socialtext::Pluggable::Plugin::Mocked;
# @COPYRIGHT@
use strict;
use warnings;

use base 'Socialtext::Pluggable::Plugin';
use Class::Field 'const';

sub register {
    my $class = shift;
}

sub test_hooks {
    my ($class, %hooks) = @_;
    no strict 'refs';
    while (my ($name, $sub) = each %hooks) {
        *{"${class}::${name}"} = $sub;
        $class->add_hook($name, $name);
    }
}

1;
