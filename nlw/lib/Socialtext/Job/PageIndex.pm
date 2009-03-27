package Socialtext::Job::PageIndex;
use strict;
use warnings;
use base qw( TheSchwartz::Worker );
use Socialtext::Jobs;
use Socialtext::Job::AttachmentIndex;
use Socialtext::Log qw/st_log/;

sub Record {
    my $class = shift;
    my $page  = shift;
    my $search_config = shift || '';

    $class->_log_page_action($page);

    Socialtext::Jobs->new->work_asynchronously(
        'PageIndex', {
            workspace_id => $page->hub->current_workspace->workspace_id,
            page_id => $page->id,
            search_config => $search_config,
        },
    );

    $class->_index_attachments_for_page($page, $search_config);
}

sub work {
    my $class = shift;
    my TheSchwartz::Job $job = shift;

    warn __PACKAGE__ . " is not implemented yet";

    $job->completed();
}

sub _log_page_action {
    my $class = shift;
    my $page  = shift;

    my $action = $page->hub->action || '';
    return if $page->hub->rest->query->param('clobber')
        || $action eq 'submit_comment'
        || $action eq 'attachments_upload';

    if ( $action eq 'edit_content' ||
         $action eq 'rename_page' ) {
         return unless $page->restored || $page->revision_count == 1;
    }

    my $log_action = ($action eq 'delete_page') ? 'DELETE' : 'CREATE';
    my $ws     = $page->hub->current_workspace;
    my $user   = $page->hub->current_user;

    st_log()->info("$log_action,PAGE,"
                   . 'workspace:' . $ws->name . '(' . $ws->workspace_id . '),'
                   . 'page:' . $page->id . ','
                   . 'user:' . $user->username . '(' . $user->user_id . '),'
                   . '[NA]'
    );
}

sub _index_attachments_for_page {
    my ( $class, $page, $search_config ) = @_;

    my $attachments = $page->hub->attachments->all( page_id => $page->id );
    foreach my $attachment (@$attachments) {
        next if $attachment->deleted();

        Socialtext::Job::AttachmentIndex->Record($attachment, $search_config);
    }
}

1;
