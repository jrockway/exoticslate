package Socialtext::Pluggable::Plugin::Default;
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
    my $person = Socialtext::User->new(
        username => $username
    );
    if ($person) {
        return $person->best_full_name . " ($username)";
    }
    return $username;
}

1;
