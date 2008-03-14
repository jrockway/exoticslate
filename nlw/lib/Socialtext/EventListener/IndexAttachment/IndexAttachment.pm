# @COPYRIGHT@
package Socialtext::EventListener::IndexAttachment::IndexAttachment;
use strict;
use warnings;

use base 'Socialtext::EventListener';
use Socialtext::Log 'st_log';

sub react {
    my ( $self, $event ) = @_;

    st_log->debug( 'ST::Ceqlotron index attachment event for '
            . $event->workspace_name . ' '
            . $event->page_uri . ' '
            . $event->attachment_id );

    return $self->_run_admin(
        $event->workspace_name,
        [
            'index-attachment',    '--attachment',
            $event->attachment_id, '--page',
            $event->page_uri,      '--workspace',
            $event->workspace_name
        ]
    );
}

1;
