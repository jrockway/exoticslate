package Socialtext::Rest::Events::Page;
# @COPYRIGHT@
use warnings;
use strict;
use base 'Socialtext::Rest::EventsBase';

use Socialtext::l10n 'loc';

sub collection_name {
    my $self = shift;
    return loc("Events for Page [_1]", $self->pname);
}

sub events_auth_method { 'page' }

sub get_resouce {
    my $self = shift;
    my $rest = shift;
    my $content_type = shift;

    my @args = $self->extract_common_args;
    push @args, 'page.id' => $self->pname;
    push @args, 'page.workspace_id' => $self->ws;

    my $events = Socialtext::Events->Get($self->rest->user, @args);
    $events ||= [];
    return $events;
}

1;
