package Socialtext::Pluggable::Plugin::Default;
# @COPYRIGHT@
use strict;
use warnings;

use base 'Socialtext::Pluggable::Plugin';
use Class::Field 'const';
const priority => 0;

sub register {
    my $class = shift;
    $class->add_hook('template.username.content', 'username');
}

sub username {
    my ($self, $username) = @_;
    my $workspace = $self->hub->current_workspace;
    my $person = Socialtext::User->new(username => $username);
    return $person
        ? $person->best_full_name( workspace => $workspace )
        : $username;
}

1;
