package Socialtext::Rest::Events::Activities;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::Rest::Events';
use Socialtext::l10n 'loc';
use Socialtext::SQL qw/sql_execute/;

use Socialtext::Events;

our $VERSION = '1.0';

sub allowed_methods {'GET'}
sub collection_name { 
    my $self = shift;
    my $user = Socialtext::User->Resolve($self->user);
    return loc("[_1]'s Activity", $user->best_full_name);
}

sub get_resource {
    my ($self, $rest) = @_;
    my @args = ($self->extract_common_args(), 
                $self->extract_page_args(),
                $self->extract_people_args());
    my $viewer = $self->rest->user;
    my $user = $self->user;

    my $events = Socialtext::Events->GetActivities($viewer, $user, @args);
    $events ||= [];
    return $events;
}
1;
