package Socialtext::Rest::Feed;
# @COPYRIGHT@
use strict;
use warnings;

use Socialtext::Authz;
use Socialtext::HTTP ':codes';
use Socialtext::Permission 'ST_READ_PERM';

use base 'Socialtext::Rest';

sub GET {
    my ($self, $rest) = @_;

    if (! $self->workspace) {
        $rest->header(
            -status => HTTP_404_Not_Found,
        );
        return 'Invalid Workspace';
    }

    my $authz = Socialtext::Authz->new;
    unless (
        $self->workspace->is_public or
        $authz->user_has_permission_for_workspace(
            user       => $self->rest->user,
            permission => ST_READ_PERM,
            workspace  => $self->workspace,
        )
        ) {

        $rest->header(
            -status             => HTTP_401_Unauthorized,
            '-WWW-Authenticate' => 'Basic realm="Socialtext"'
        );
        return 'Invalid Workspace';
    }

    # put a rest object on the hub so we can use it
    # elsewhere when doing Socialtext::CGI operations
    $self->hub->rest($rest);

    # XXX uses default type and category, need to improve that
    # syndicate($type, $category)
    my $feed = eval { $self->hub->syndicate->syndicate };

    if (Exception::Class->caught('Socialtext::Exception::NoSuchPage')) {
        $rest->header(
            -status => HTTP_404_Not_Found,
        );
        return 'Page Not Found';
    }

    if ($@ and not Exception::Class->caught('MasonX::WebApp::Exception::Abort')) {
        $rest->header(
            -status => HTTP_500_Internal_Server_Error,
        );
        return $@;
    }

    $rest->header(
        -status => HTTP_200_OK,
        -type => $feed->content_type,
    );
    return $feed->as_xml;
}

1;

