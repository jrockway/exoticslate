# @COPYRIGHT@
package Socialtext::EventListener::Workspace::IndexWorkspace;
use strict;
use warnings;

use base 'Socialtext::EventListener';
use Socialtext::Log 'st_log';

sub react {
    my ( $self, $event ) = @_;

    st_log->info(
        'ST::Ceqlotron workspace event for ' . $event->workspace_name );

    return $self->_run_admin( $event->workspace_name,
        [ 'index-workspace', '--workspace', $event->workspace_name ] );
}

1;
