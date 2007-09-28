# @COPYRIGHT@
package Socialtext::EventListener::IndexPage::IndexPage;
use strict;
use warnings;

use base 'Socialtext::EventListener';
use Socialtext::Log 'st_log';

sub react {
    my ( $self, $event ) = @_;

    st_log->info( 'ST::Ceqlotron indexpage event for '
          . $event->workspace_name . ' '
          . $event->page_uri );

    return $self->_run_admin(
        $event->workspace_name,
        [
            'index-page',           '--workspace',
            $event->workspace_name, '--page',
            $event->page_uri
        ]
    );
}

1;
