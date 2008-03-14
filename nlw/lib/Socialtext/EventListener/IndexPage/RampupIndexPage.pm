# @COPYRIGHT@
package Socialtext::EventListener::IndexPage::RampupIndexPage;
use strict;
use warnings;

use Socialtext::Search::Config;

use base 'Socialtext::EventListener';
use Socialtext::Log 'st_log';

sub react {
    my ( $self, $event ) = @_;

    if (Socialtext::Search::Config->new(mode => 'rampup')) {
        st_log->debug( 'ST::Ceqlotron rampup index page event for '
              . $event->workspace_name . ' '
              . $event->page_uri );

        return $self->_run_admin(
            $event->workspace_name,
            [
                'index-page',           '--workspace',
                $event->workspace_name, '--page',
                $event->page_uri,       '--search-config',
                'rampup'
            ]
        );
    }
    else {
        return $self->_run_noop();
    }
}

1;
