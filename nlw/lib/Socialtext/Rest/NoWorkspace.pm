package Socialtext::Rest::NoWorkspace;
# @COPYRIGHT@

use strict;
use warnings;

use base 'Socialtext::Rest';

use Socialtext::AppConfig;
use Socialtext::HTTP ':codes';
use Socialtext::Log 'st_log';
use Socialtext::Permission 'ST_READ_PERM';
use Socialtext::User;
use Socialtext::Workspace;

# XXX There may be some issues with session handling
# here. Not sure if they are new or not new.

sub handler {
    my ($self, $rest) = @_;

    my $user = $rest->user;

    Socialtext::Challenger->Challenge() unless $user;

    my $session = Socialtext::Session->new();
    my $browsers_last_workspace = Socialtext::Workspace->new(
        workspace_id => $session->last_workspace_id() );

    my $destination_ws;
    if ($browsers_last_workspace) {
        my $user_can_access_last_workspace
            = $browsers_last_workspace->permissions->user_can(
            permission => ST_READ_PERM,
            user       => $user
        );

        if ($user_can_access_last_workspace) {
            $destination_ws = $browsers_last_workspace;
        }
    }

    $destination_ws ||= $user->workspaces->next;

    $destination_ws ||= Socialtext::Workspace->new(
        name => Socialtext::AppConfig->default_workspace() );

    $destination_ws ||= Socialtext::Workspace->new(
        name => 'help' );

    if ($destination_ws) {
        return _redirect( $rest, $destination_ws->uri() . 'index.cgi', $user );
    }

    # If we get here something has gone rather wrong, since the call
    # to ST::AppConfig->default_workspace() should be giving us
    # something valid, and even if that is bad, then there should be a
    # help workspace!
    my $support_address = Socialtext::AppConfig->support_address();

    # We can't find anywhere to go, so tell the user about it.
    $session->add_error(<<"ERROR_MSG"
Login error: no user/workspace match.  The system was not able to log you into
the wiki.  Please send email to $support_address and tell us which wiki
you were trying to log in to, so we can fix the problem.
ERROR_MSG
    );

    return _redirect( $rest, '/nlw/login.html', $user );
}

sub _redirect {
    my $rest = shift;
    my $uri = shift;
    my $user = shift;

    $rest->header(
        -status => HTTP_302_Found,
        -Location => $uri,
    );

    my $email = $user ? $user->email_address : "unknown user";
    st_log->info("NoWorkspace: Redirecting $email to $uri");

    return '';
}

1;
