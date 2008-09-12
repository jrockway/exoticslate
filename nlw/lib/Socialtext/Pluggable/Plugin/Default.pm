package Socialtext::Pluggable::Plugin::Default;
# @COPYRIGHT@
use strict;
use warnings;

use Socialtext::Rest::NoWorkspace;
use base 'Socialtext::Pluggable::Plugin';
use Class::Field 'const';
const priority => 0;

sub register {
    my $class = shift;
    $class->add_hook('root'                         => 'root');
    $class->add_hook('template.user_avatar.content' => 'user_name');
    $class->add_hook('template.user_name.content'   => 'user_name');
    $class->add_hook('template.user_image.content'  => 'user_image');
    $class->add_hook('wafl.user'                    => 'user_name');
}

sub root {
    my ($self, $rest) = @_;
    my $nowork = Socialtext::Rest::NoWorkspace->new($rest);
    return $nowork->handler($rest);
}

sub user_name {
    my ($self, $username) = @_;
    warn "DEFAULT USER NAME for $username\n";
    return $self->best_full_name($username);
}

sub user_image { '' }

sub is_hook_enabled { 1 }

1;
