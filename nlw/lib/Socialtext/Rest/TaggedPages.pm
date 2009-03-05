package Socialtext::Rest::TaggedPages;
# @COPYRIGHT@

use warnings;
use strict;

use base 'Socialtext::Rest::Pages';

# REVIEW: This need to be different depending on the query?
sub collection_name {
    'Pages tagged with ' . $_[0]->tag;
}

sub element_list_item {
    my ( $self, $page ) = @_;

    return "<li><a href='/data/workspaces/$page->{workspace_name}/pages/$page->{page_id}'>"
        . Socialtext::String::html_escape( $page->{name} )
        . "</a></li>\n";
}

# Generates an unordered, unsorted list of pages which satisfy the query
# parameters.
sub _entities_for_query {
    my $self = shift;

    my $limit = $self->rest->query->param('limit')
                || $self->rest->query->param('count')
                || 500;

    my $pagesref = [];
    if (lc($self->tag) eq 'recent changes') {
        my $prefs = $self->hub->recent_changes->preferences;
        my $seconds = $prefs->changes_depth->value * 1440 * 60;
        $pagesref = Socialtext::Model::Pages->By_seconds_limit(
            seconds          => $seconds,
            hub              => $self->hub,
            limit            => $limit,
            do_not_need_tags => 1,
            workspace_id => $self->hub->current_workspace->workspace_id,
        );
    }
    else {
        $pagesref = Socialtext::Model::Pages->By_tag(
            hub => $self->hub,
            tag => $self->tag,
            workspace_id => $self->hub->current_workspace->workspace_id,
            limit => $limit,
        );
    }
    return @$pagesref;
}

sub allowed_methods {
    return 'GET, HEAD';
}

1;
