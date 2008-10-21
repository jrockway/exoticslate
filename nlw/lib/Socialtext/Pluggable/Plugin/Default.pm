package Socialtext::Pluggable::Plugin::Default;
# @COPYRIGHT@
use strict;
use warnings;
use Socialtext::BrowserDetect;

use base 'Socialtext::Pluggable::Plugin';
use Class::Field 'const';
const priority => 0;

sub register {
    my $class = shift;
    $class->add_hook('root'                              => 'root');
    $class->add_hook('template.user_avatar.content'      => 'user_name');
    $class->add_hook('template.user_name.content'        => 'user_name');
    $class->add_hook('template.user_small_photo.content' => 'user_photo');
    $class->add_hook('template.user_photo.content'       => 'user_photo');
    $class->add_hook('wafl.user'                         => 'user_name');
}

sub root {
    my ($self, $rest) = @_;
    my $is_mobile = Socialtext::BrowserDetect::is_mobile();

    # logged in users go to the Workspace List
    my $user = $rest->user();
    if ($user and not $user->is_guest) {
        my $ws_list_uri = $is_mobile ? '/lite/workspace_list' : 'action=workspace_list';
        return $self->redirect( $ws_list_uri );
    }

    # everyone else goes to the login page (with embedded public Workspace
    # List)
    my $login_uri = $is_mobile ? '/lite/login' : '/nlw/login.html';
    return $self->redirect( $login_uri );
}

sub user_name {
    my ($self, $username) = @_;
    return $self->best_full_name($username);
}

sub user_photo { '' }

sub is_hook_enabled { 1 }

1;
