# @COPYRIGHT@
package Socialtext::Events;
use warnings;
use strict;

use Class::Field qw(const);
use Socialtext::HTTP ':codes';
use Socialtext::Events::Recorder;
use Socialtext::Events::Reporter;
use Carp qw/croak/;

sub Get {
    my $class = shift;
    my $viewer = shift || croak 'must supply viewer';
    my $reporter = Socialtext::Events::Reporter->new(viewer => $viewer);
    return $reporter->get_events(@_);
}

sub GetActivities {
    my $class = shift;
    my $viewer = shift || croak 'must supply viewer';
    my $user = shift || croak 'must supply user to view (or maybe you just passed in one user to this function)';
    my $reporter = Socialtext::Events::Reporter->new(viewer => $viewer);
    return $reporter->get_events_activities($user, @_);
}

sub Record {
    my $class = shift;
    my $ev = shift;

    if ($ev->{event_class} && $ev->{event_class} eq 'page' &&
        $ev->{page} && ref($ev->{page}))
    {
        my $page = $ev->{page};
        $ev->{actor} ||= $page->hub->current_user;
        $ev->{workspace} ||= $page->hub->current_workspace;
        $ev->{context} ||= {};
        $ev->{context}{revision_count} ||= $page->revision_count;
        $ev->{context}{revision_id} ||= $page->revision_id;
        if (my $es = $page->edit_summary) {
            $ev->{context}{edit_summary} ||= $es;
        }

        my $t_page = delete $ev->{target_page};
        my $t_page_workspace = delete $ev->{target_workspace};
        my $t_page_id = $t_page->id if $t_page;
        my $t_ws_name = $t_page_workspace->name if $t_page_workspace;
        $ev->{context}{target_page}{id} = $t_page_id if $t_page_id;
        $ev->{context}{target_page}{workspace_name} = $t_ws_name if $t_ws_name;

        $ev->{context}{summary} = delete $ev->{summary}
            if $ev->{summary};
    }

    my $recorder = Socialtext::Events::Recorder->new;
    return $recorder->record_event($ev);
}

1;
