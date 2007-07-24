# @COPYRIGHT@
package Socialtext::Handler::NoWorkspace;

use strict;
use warnings;

use Apache::Constants qw(REDIRECT);
use Socialtext::Apache::User;
use Socialtext::AppConfig;
use Socialtext::Log 'st_log';
use Socialtext::Permission 'ST_READ_PERM';
use Socialtext::User;
use Socialtext::Workspace;

sub handler {
    my $r = shift;

    my $user = Socialtext::Apache::User::current_user($r);

    Socialtext::Challenger->Challenge() unless $user;

    my $session = Socialtext::Session->new();
    my $browsers_last_workspace = Socialtext::Workspace->new(
        workspace_id => $session->last_workspace_id() );

    my $destination_ws;
    if ($browsers_last_workspace) {
        my $user_can_access_last_workspace
            = $browsers_last_workspace->user_has_permission(
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
        return _redirect( $r, $destination_ws->uri(), $user );
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

    return _redirect( $r, '/nlw/login.html', $user );
}

sub _redirect {
    my $r = shift;
    my $uri = shift;
    my $user = shift;

    $r->status(REDIRECT);
    $r->err_header_out( Location => $uri );
    $r->send_http_header;

    my $email = $user ? $user->email_address : "unknown user";
    st_log->info("NoWorkspace: Redirecting $email to $uri");

    return REDIRECT;
}

1;
