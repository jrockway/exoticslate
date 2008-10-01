package Socialtext::Rest::Events::Conversations;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest::Events';

use Socialtext::Events;
use Socialtext::User;

sub allowed_methods {'GET'}
sub collection_name { "Conversation Events" }

sub get_resource {
    my ($self, $rest) = @_;
    # TODO: add limit, offset
    my $viewer = $self->rest->user;
    my $user = eval { Socialtext::User->Resolve($self->user) };

    if (!$viewer || !$user || $viewer->user_id != $user->user_id) {
        die Socialtext::Exception::Auth->new(
            "A user can only view their own conversations");
    }
    # TODO: pass down limit and offset.
    my $events = Socialtext::Events->GetConversations($user);
    $events ||= [];
    return $events;
}
1;
