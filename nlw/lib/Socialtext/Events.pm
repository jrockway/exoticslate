# @COPYRIGHT@
package Socialtext::Events;
use warnings;
use strict;

use base 'Socialtext::Plugin';

use Class::Field qw(const);
use Socialtext::HTTP ':codes';
use Socialtext::Events::Recorder;
use Socialtext::Events::Reporter;

sub class_id { 'events' }
const cgi_class => 'Socialtext::Events::CGI';

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(action => 'log_event');
}


sub log_event {
    my $self = shift;

    my $class = $self->cgi->class || 'page';
    my $action = $self->cgi->event
        or die "Need to supply an action";


    if ($class ne 'page') {
        $self->hub->headers->status(HTTP_400_Bad_Request);
        return "Can't send non-page events to this URI";
    }

    if ($action =~ /^edit_/ && $self->cgi->page_id eq 'untitled_page') {
        $self->hub->headers->status(HTTP_400_Bad_Request);
        return "Can't edit untitled_page";
    }

    my $page = $self->hub->pages->new_page($self->cgi->page_id);

    Socialtext::Events->Record({
        class => 'page',
        action => $action,
        page => $page,
    });

    return "Event Logged.";
}

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

package Socialtext::Events::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'event';
cgi 'class';
cgi 'page_id';
cgi 'revision_count';
cgi 'revision_id';

1;
