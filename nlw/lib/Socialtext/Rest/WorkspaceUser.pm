package Socialtext::Rest::WorkspaceUser;

# @COPYRIGHT@

use warnings;
use strict;

use base 'Socialtext::Rest::Entity';

use Socialtext::HTTP ':codes';
use Socialtext::User;
use Socialtext::Workspace;

sub allowed_methods {'DELETE'}

# Remove a user from a workspace
sub DELETE {
    my ( $self, $rest ) = @_;

    return $self->no_workspace() unless $self->workspace;

    my $target_user = Socialtext::User->new( username => $self->username );
    if ( $self->_admin_or_user_reflect($target_user) ) {
        unless ( $target_user && $self->workspace->has_user($target_user) ) {
            $rest->header( -status => HTTP_404_Not_Found );
            return $self->username
                . " is not a member of "
                . $self->workspace->name;
        }
        $self->workspace->remove_user( user => $target_user );
        $rest->header( -status => HTTP_204_No_Content );
        return '';
    }
    else {
        return $self->not_authorized();
    }
}

sub _admin_or_user_reflect {
    my $self        = shift;
    my $target_user = shift;

    return $self->hub->checker->check_permission('admin_workspace')
        || ( $target_user
        && $self->rest->user->user_id eq $target_user->user_id );
}


# SFP
1;
