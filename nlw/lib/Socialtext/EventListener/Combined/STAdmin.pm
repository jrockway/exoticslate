# @COPYRIGHT@
package Socialtext::EventListener::Combined::STAdmin;
use strict;
use warnings;

use base 'Socialtext::EventListener';
use Socialtext::Log 'st_log';

sub react {
    my ( $self, $event ) = @_;

    st_log->debug( 'ST::Ceqlotron combined page event for '
            . $event->workspace_name . ' '
            . $event->page_uri );

    return $self->_run_admin(
        $event->workspace_name,
        map {
            [ $_, '--workspace', $event->workspace_name, '--page',
                $event->page_uri ]
            } qw(send-weblog-pings send-email-notifications send-watchlist-emails index-page)
    );
}

1;
