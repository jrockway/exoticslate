# @COPYRIGHT@
package Socialtext::Events;
use warnings;
use strict;

use Class::Field qw(const);
use Socialtext::HTTP ':codes';
use Socialtext::Events::Recorder;
use Socialtext::Events::Reporter;

sub Get {
    my $class = shift;
    return Socialtext::Events::Reporter->new->get_events(@_);
}

sub Record {
    my $class = shift;
    my $ev = shift;

    if ($ev->{class} && $ev->{class} eq 'page' &&
        $ev->{page} && ref($ev->{page}))
    {
        my $page = $ev->{page};
        $ev->{actor} ||= $page->hub->current_user;
        $ev->{workspace} ||= $page->hub->current_workspace;
        $ev->{context} ||= {};
        $ev->{context}{revision_count} ||= $page->revision_count;
        $ev->{context}{revision_id} ||= $page->revision_id;

        my $target_page_id = delete $ev->{target_page_id};
        my $target_page_workspace_id = delete $ev->{target_workspace_id};
        $ev->{context}{target_page_id} = $target_page_id 
            if $target_page_id;
        $ev->{context}{target_page_workspace_id} = $target_page_workspace_id
            if $target_page_workspace_id;

        $ev->{context}{summary} = delete $ev->{summary}
            if $ev->{summary};
    }

    my $recorder = Socialtext::Events::Recorder->new;
    return $recorder->record_event($ev);
}

1;
