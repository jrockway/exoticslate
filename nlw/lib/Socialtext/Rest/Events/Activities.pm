package Socialtext::Rest::Events::Activities;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest::Events';
use Socialtext::SQL qw/sql_execute/;

use Socialtext::Events;

our $VERSION = '1.0';

sub allowed_methods {'GET'}
sub collection_name { "Activity Events" }

sub get_resource {
    my ($self, $rest) = @_;
    # TODO: add limit, offset
    my $viewer = $self->rest->user;
    my $user = $self->user;
    my $events = Socialtext::Events->GetActivities($viewer, $user);
    $events ||= [];
    return $events;
}
1;
