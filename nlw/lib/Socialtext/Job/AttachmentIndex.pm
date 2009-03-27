package Socialtext::Job::AttachmentIndex;
use strict;
use warnings;
use base qw( TheSchwartz::Worker );
use Socialtext::Jobs;
use base 'Socialtext::Job';

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
    my $args = $job->arg;

    my $wksp = Socialtext::Workspace->new(workspace_id => $args->{workspace_id});
    my $indexer = $class->_create_indexer($wksp, $args->{search_config}) or return;
    $indexer->index_attachment( $args->{page_id}, $args->{attach_id} );

    # Is this really necessary?
    # $indexer->index_page( $page->id() );

    $job->completed();
}

1;
