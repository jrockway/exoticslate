package Socialtext::Pluggable::Plugin::Default;
# @COPYRIGHT@
use strict;
use warnings;

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

    # logged in users go to the Workspace List
    my $user = $rest->user();
    if ($user and not $user->is_guest) {
        return $self->redirect( 'action=workspace_list' );
    }

    # everyone else goes to the login page (with embedded public Workspace
    # List)
    return $self->redirect( '/nlw/login.html' );
}

sub user_name {
    my ($self, $username) = @_;
    return $self->best_full_name($username);
}

sub user_image { '' }

sub is_hook_enabled { 1 }

1;
