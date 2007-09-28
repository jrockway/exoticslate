# @COPYRIGHT@
package Socialtext::EventListener::IndexAttachment::RampupIndexAttachment;
use strict;
use warnings;

use Socialtext::Search::Config;

use base 'Socialtext::EventListener';
use Socialtext::Log 'st_log';

sub react {
    my ( $self, $event ) = @_;

    if (Socialtext::Search::Config->new(mode => 'rampup')) {
        st_log->info( 'ST::Ceqlotron rampup attachment event for '
                . $event->workspace_name . ' '
                . $event->page_uri . ' '
                . $event->attachment_id );

        return $self->_run_admin(
            $event->workspace_name,
            [
                'index-attachment',     '--attachment',
                $event->attachment_id,  '--page',
                $event->page_uri,       '--workspace',
                $event->workspace_name, '--search-config',
                'rampup'
            ]
        );
    }
    else {
        return $self->_run_noop();
    }
}

1;
