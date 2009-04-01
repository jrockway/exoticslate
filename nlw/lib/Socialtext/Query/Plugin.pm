# @COPYRIGHT@
package Socialtext::Query::Plugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use Socialtext::User;
use Class::Field qw( const field );
use Storable ();

# XXX Rather than doing all this sortdir crap and the related
# caching, we should get javascript sortable tables in there.
# The question to answer with that, though, is if we would
# need to degrade well in a non javascript situation?
const sortdir => {
    Summary        => 'asc',
    Subject        => 'asc',
    Date           => 'desc',
    revision_count => 'desc',
    username       => 'asc',
};

const listview_extra_columns => {};

field result_set =>
      -init => '$self->read_result_set';

field 'error_message';
field 'sortby';

# Per object (request) cache mapping a workspace name to a 
# Workspace object;
field '_workspace_cache' => {};

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(action => $self->class_id);
}

sub get_result_set_path {
    my $self = shift;
    join '/',
        $self->user_plugin_directory( $self->hub->current_user->email_address ),
        $self->class_id . '_result_set',
    ;
}

sub push_result {
    my $self = shift;
    my $page = shift;
    push @{$self->result_set->{rows}}, $page->to_result;
    return 1;
}

sub read_result_set {
    my $self = shift;
    my $result_set_path = $self->get_result_set_path;
    return $self->default_result_set
        unless -f $result_set_path;

    my $result_set = eval {
        Storable::lock_retrieve($result_set_path)
    };
    return $result_set unless $@;

    unlink $result_set_path;
    $self->new_result_set;
}

sub write_result_set {
    my $self = shift;
    Storable::lock_store(
        $self->result_set,
        $self->get_result_set_path,
    );
}

sub dont_use_cached_result_set {
    my $self = shift;
    my $result_set_path = $self->get_result_set_path;
    unlink $result_set_path;
}

# XXX when we send a result set to the template
# perhaps it could be just a list of pages. This
# presents difficulties with the attachments that
# are found for search results.
sub display_results {
    my $self = shift;
    my $sortdir = shift;

    my $sortby = $self->sortby || $self->cgi->sortby || 'Date';
    my $direction = $self->cgi->direction || $sortdir->{ $sortby };

    $self->screen_template('view/listview');

    my $result_set = $self->result_set;
    $self->result_set(undef);
    $self->render_screen(
        %$result_set,
        summaries              => $self->show_summaries,
        sortby                 => $sortby,
        sortdir                => $sortdir,
        direction              => $direction,
        error_message          => $self->error_message,
        listview_extra_columns => $self->listview_extra_columns,
        @_,
    );
}

sub show_summaries {
    my $self = shift;

    return $self->cgi->summaries || 0;
}

sub sorted_result_set {
    my $self = shift;
    my $sortdir_map = shift;
    my $limit = shift;

    my $sortby = $self->sortby || $self->cgi->sortby || 'Date';
    my $direction = $self->cgi->direction || $sortdir_map->{$sortby};
    my $sortsub
        = $self->_gen_sort_closure( $sortby, $direction );

    my $row_num = 1;
    my $result_set = $self->result_set;
    @{$result_set->{rows}} = map {
        $_->{row_num} = $row_num;
        $_->{odd} = $row_num++ % 2;
        $_;
    } sort $sortsub @{$result_set->{rows}};
    splice @{$result_set->{rows}}, $limit
        if defined($limit) and @{$result_set->{rows}} > $limit;
    return $result_set;
}

sub _gen_sort_closure {
    my $self        = shift;
    my $sortby      = shift; # the attribute being sorted on
    my $direction   = shift || ''; # the direction ('asc' or 'desc')

    if ( $sortby eq 'revision_count' ) { # The only integral attribute, so use numeric sort
        if ( $direction eq 'asc' ) {
            return sub {
                $a->{revision_count} <=> $b->{revision_count}
                    or lc( $a->{Subject} ) cmp lc( $b->{Subject} );
                }
        }
        else {
            return sub {
                $b->{revision_count} <=> $a->{revision_count}
                    or lc( $a->{Subject} ) cmp lc( $b->{Subject} );
                }
        }
    }
    elsif ( $sortby eq 'username' ) { 
        # we want to sort by whatever the system knows these users as, which
        # may not be the same as the From header.
        if ( $direction eq 'asc' ) {
            return sub {
                lc( Socialtext::User->new( 
                    username => $a->{username} 
                )->guess_sortable_name )
                cmp 
                lc( Socialtext::User->new(
                    username => $b->{username}
                )->guess_sortable_name )
                or lc( $a->{Subject} ) cmp lc( $b->{Subject} );
            }
        }
        else {
            return sub {
                lc( Socialtext::User->new( 
                    username => $b->{username} 
                )->guess_sortable_name )
                cmp 
                lc( Socialtext::User->new(
                    username => $a->{username}
                )->guess_sortable_name )
                or lc( $b->{Subject} ) cmp lc( $a->{Subject} );
            }
        }
    }
    else { # anything else, most likely a string
        if ( $direction eq 'asc' ) {
            return sub {
                lc( $a->{$sortby} ) cmp lc( $b->{$sortby} )
                    or lc( $a->{Subject} ) cmp lc( $b->{Subject} );
            };
        }
        else {
            return sub {
                lc( $b->{$sortby} ) cmp lc( $a->{$sortby} )
                    or lc( $a->{Subject} ) cmp lc( $b->{Subject} );
            };
        }
    }
}

sub default_result_set {
    my $self = shift;
    $self->new_result_set;
}

sub new_result_set {
    my $self = shift;
    {
        rows => [],
        hits => 0,
        display_title => '',
        predicate => 'action=' . $self->class_id,
    }
}

# Fetch pages in the bulk per workspace for search results
# We'll stick the pageref in the hit object for later
sub _load_pages_for_hits {
    my $self = shift;
    my $hits = shift;
    
    my %pages;
    for my $hit (@$hits) {
        push @{$pages{$hit->workspace_name}{$hit->page_uri}}, $hit;
    }
    for my $workspace_name (keys %pages) {
        my ($workspace, $hit_hub)
            = $self->_load_hit_workspace_and_hub($workspace_name);
        my $wksp_pages = $pages{$workspace_name};
        my $pages = [];
        eval {
            $pages = Socialtext::Model::Pages->By_id(
                hub              => $hit_hub,
                workspace_id     => $workspace->workspace_id,
                page_id          => [ keys %$wksp_pages ],
                do_not_need_tags => 1,
            );
        };
        warn $@ if $@;
        $pages = [$pages] unless (ref($pages) || '') eq 'ARRAY';

        for my $page (@$pages) {
            my $page_hits = $wksp_pages->{$page->id};
            for my $hit (@$page_hits) {
                $hit->{page} = $page;
            }
        }
    }
}

sub _load_hit_workspace_and_hub {
    my $self = shift;
    my $workspace_name  = shift;

    if (my $hit = $self->_workspace_cache->{$workspace_name}) {
        return ($hit->{workspace}, $hit->{hub});
    }

    # Establish the proper hub for the hit
    my $hub = $self->hub;
    my $workspace;
    eval { $workspace = Socialtext::Workspace->new(name => $workspace_name) };
    if ( $workspace->name ne $hub->current_workspace->name ) {
        my $main = Socialtext->new();
        $main->load_hub(
            current_user      => $hub->current_user,
            current_workspace => $workspace
        );
        $main->hub->registry->load;
        $hub = $main->hub;
    }

    # Seed the cache for next time
    $self->_workspace_cache->{$workspace_name} = {
        workspace => $workspace,
        hub       => $hub,
    };
    return ($workspace, $hub);
}

sub _make_row {
    my ( $self, $hit ) = @_;

    my ($workspace, $hit_hub)
        = $self->_load_hit_workspace_and_hub($hit->workspace_name);

    my $page_uri = $hit->page_uri;
    my $page;
    eval {
        $page = $hit->{page} || Socialtext::Model::Pages->By_id(
            hub          => $hit_hub,
            workspace_id => $workspace->workspace_id,
            page_id      => $page_uri,
        );
    };
    return {} if !$page or $page->deleted;

    my $author = $page->last_edited_by;
    my $document_title = $page->title;
    my $date = $page->last_edit_time;
    my $date_local = $page->datetime_for_user;
    my $snippet = $hit->snippet || $page->summary;
    my $id = $page->id;
    my $attachment;
    if ( $hit->isa('Socialtext::Search::AttachmentHit') ) {
        my $attachment_id = $hit->attachment_id;
        $attachment = $hit_hub->attachments->new_attachment(
            id      => $attachment_id,
            page_id => $page_uri,
        )->load();

        return {} if $attachment->deleted;
        $snippet = $hit->snippet || $attachment->preview_text;
        $document_title = $attachment->{filename};
        $date = $attachment->{Date};
        $date_local = $self->hub->timezone->date_local( $date );
        $id = $attachment->id;
        $author = $attachment->uploaded_by;
    }

    return +{
        Relevance           => $hit->hit->{score},
        Date                => $date,
        Revision            => $page->current_revision_num,
        Summary             => $snippet,
        document_title      => $document_title,
        Subject             => $page->title,
        DateLocal           => $date_local,
        revision_count      => $page->revision_count,
        page_uri            => $page->uri,
        page_id             => $page->id,
        id                  => $id,
        username            => $author->username,
        Workspace           => $workspace->title,
        workspace_name      => $workspace->name,
        workspace_title     => $workspace->title,
        is_attachment       => $hit->isa('Socialtext::Search::AttachmentHit'),
        is_spreadsheet      => $page->is_spreadsheet,
        edit_summary        => $page->edit_summary,
    };
}

1;
