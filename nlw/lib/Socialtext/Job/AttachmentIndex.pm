package Socialtext::Job::AttachmentIndex;
use strict;
use warnings;
use base qw( TheSchwartz::Worker );
use Socialtext::Jobs;

sub Record {
    my $class = shift;
    my $attach  = shift;
    my $search_config = shift;

    Socialtext::Jobs->new->work_asynchronously(
        'AttachmentIndex', {
            workspace_id => $attach->hub->current_workspace->workspace_id,
            page_id => $attach->page_id,
            attach_id => $attach->id,
            search_config => $search_config,
        },
    );
}

sub work {
    my $class = shift;
    my TheSchwartz::Job $job = shift;

    warn __PACKAGE__ . " is not implemented yet";

    $job->completed();
}

1;
