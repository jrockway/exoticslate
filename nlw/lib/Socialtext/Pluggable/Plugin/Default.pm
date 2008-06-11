package Socialtext::Pluggable::Plugin::Default;
# @COPYRIGHT@
use strict;
use warnings;

use base 'Socialtext::Pluggable::Plugin';
use Class::Field 'const';
const priority => 0;

sub register {
    my $class = shift;
    $class->add_hook('template.user_avatar.content', 'user_name');
    $class->add_hook('template.user_name.content', 'user_name');
    $class->add_hook('template.user_image.content', 'user_image');
}

sub user_image { '' }

sub user_name {
    my ($self, $username) = @_;
    return $self->best_full_name($username);
}

1;
