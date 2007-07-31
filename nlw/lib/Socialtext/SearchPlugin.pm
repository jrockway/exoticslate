# @COPYRIGHT@
package Socialtext::SearchPlugin;
use strict;
use warnings;

use base 'Socialtext::Query::Plugin';

use Class::Field qw( const field );
use Socialtext::Search::AbstractFactory;
use Socialtext::Pages;
use Socialtext::l10n qw(loc);

sub class_id { 'search' }
const class_title => 'Search';
const cgi_class => 'Socialtext::Search::CGI';

const sortdir => {
    Summary        => 1,
    Subject        => 0,
    From           => 0,
    Date           => 1,
    revision_count => 1,
};

field 'category_search';
field 'title_search';

=head1 DESCRIPTION

This module acts as an adaptor between the Socialtext::Query::Plugin and associated
template interfaces and the Socialtext::Search index/search abstractions.

This keeps our old search-type URLs and templates working with any search
index that implements the interfaces in the Socialtext::Search namespace.

=cut

sub register {
    my $self = shift;
    $self->SUPER::register(@_);
    my $registry = shift;
    $registry->add( wafl => search => 'Socialtext::Search::Wafl' );
    $registry->add( wafl => search_full => 'Socialtext::Search::Wafl' );
}

sub search {
    my $self = shift;
    my %sortdir = %{$self->sortdir};
    if ( $self->cgi->defined('search_term') ) {
        $self->hub->log->debug( 'performing search for '
                . $self->cgi->search_term
                . ' in workspace '
                . $self->hub->current_workspace->name );
        $self->search_for_term($self->cgi->search_term);
    }
    $self->result_set( $self->sorted_result_set( \%sortdir ) );

    my $uri_escaped_search_term
        = $self->uri_escape( $self->cgi->search_term );
    $self->display_results(
        \%sortdir,
        feeds => $self->_feeds(
            $self->hub->current_workspace, $self->cgi->search_term
        ),
        title      => loc('Search Results'),
        unplug_uri => "?action=unplug;search_term="
            . $uri_escaped_search_term,
        unplug_phrase =>
            loc('Click this button to save the pages from this search to your computer for offline use'),
    );
}

sub _feeds {
    my $self      = shift;
    my $workspace = shift;
    my $query     = shift;

    my $uri_escaped_query  = $self->uri_escape($query);

    my $root  = $self->hub->syndicate->feed_uri_root($workspace);
    # REVIEW: Even though these are not page feeds, they are called
    # page because the template share/template/view/listview looks
    # for rss.page.url to display a feed on the page.
    my %feeds = (
        rss => {
            page => {
                title => loc('[_1] - RSS Search for [_2]', $workspace->title, $query)
,
                url => $root . "?search_term=$uri_escaped_query",
            },
        },
        atom => {
            page => {
                title => loc('[_1] - Atom Search for [_2]', $workspace->title, $query),
                url => $root . "?search_term=$uri_escaped_query;type=Atom",
            },
        },
    );

    return \%feeds;
}

sub search_for_term {
    my $self = shift;
    my $search_term = shift;
    $self->hub->log->debug("searchquery '" . $search_term . "'");

    $self->result_set( $self->new_result_set );
    eval {
        @{ $self->result_set->{rows} } = $self->_new_search($search_term);
        $self->title_search( $search_term =~ s/^=// );
        $self->hub->log->debug("hitcount " . scalar @{ $self->result_set->{rows} });
        foreach my $row ( @{ $self->result_set->{rows} } ) {
            $self->hub->log->debug("hitrow $row->{page_uri}");
            $self->hub->log->debug("hitkeys @{ [keys %$row ] }");
        }
        $self->result_set->{hits}          = scalar @{ $self->result_set->{rows} };
        if( $self->title_search ) {
            $self->result_set->{display_title} = loc("Titles containing \'[_1]\' ([_2])", $search_term, $self->result_set->{hits})
        } else {
            $self->result_set->{display_title} = loc("Pages containing \'[_1]\' ([_2])", $search_term, $self->result_set->{hits})
        }
        $self->result_set->{predicate} = 'action=search';
        $self->write_result_set;
    };
    if ($@) {
        if ($@ =~ /malformed query/) {
            $self->error_message($self->template_process(
                    'search_help_field.html',
                )
            );
        }
        else {
            $self->hub->log->warning("searchdie '$@'");
        }
    }
}

sub _new_search {
    my $self = shift;
    my $query_string = shift;

    my @hits = Socialtext::Search::AbstractFactory->GetFactory->create_searcher(
        $self->hub->current_workspace->name
    )->search($query_string);

    my ( %page_row, @attachment_rows );
    foreach my $hit (@hits) {
        $page_row{ $hit->page_uri } = $self->_make_page_row( $hit->page_uri )
            if $hit->isa('Socialtext::Search::PageHit');
    }
    foreach my $hit (@hits) {
        if ($hit->isa('Socialtext::Search::AttachmentHit')) {
            $page_row{ $hit->page_uri }
                = $self->_make_page_row( $hit->page_uri )
                unless exists $page_row{ $hit->page_uri };

            push @{ $page_row{ $hit->page_uri }->{attachments} },
                $self->_make_attachment_row(
                    $hit->page_uri,
                    $hit->attachment_id
                );
        }
    }

    # Only add non-empty rows to the result_set.
    return grep { keys %$_ } values %page_row;
}

sub _make_page_row {
    my $self = shift;
    my $page_uri = shift;
    my $page     = $self->hub->pages->new_page($page_uri);

    return {} if $page->deleted;

    my $metadata = $page->metadata;

    my $author   = $page->last_edited_by;

    # $author will be undef if the page_uri in the index
    # does not correspond with any existing page. This can happen
    # when pages with page ids are created (happened in the
    # way past, but is cleared up now).
    unless ($author) {
        $self->hub->log->warning( 'search result skipped: '
                . $self->hub->current_workspace->name . ': \''
                . $page_uri
                . '\' has no author or is a bad page id' );
        return {};
    }

    my $author_name = $author->best_full_name(
        workspace => $self->hub->current_workspace );

    return +{
        ( map { ( $_ => $metadata->$_ ) }
            (qw(From Date Subject Revision Summary)) ),
        DateLocal      => $page->datetime_for_user,
        revision_count => scalar $page->all_revision_ids,
        page_uri       => $page->uri,
        page_id        => $page->id,
        From           => $author_name,
    };
}

sub _make_attachment_row {
    my $self = shift;
    my $page_uri = shift;
    my $attachment_id = shift;

    my $attachment = $self->hub->attachments->new_attachment(
        id      => $attachment_id,
        page_id => $page_uri,
    )->load;

    return $attachment->deleted
        ? {}
        : {
        id        => $attachment->id,
        filename  => $attachment->filename,
        DateLocal => $self->hub->timezone->date_local( $attachment->{Date} ),
        };
}

sub get_result_set {
    my $self = shift;
    my $search_term = shift;
    my %sortdir = %{$self->sortdir};
    $self->search_for_term($search_term);
    return $self->sorted_result_set(\%sortdir);
}

sub write_result_set {
    my $self = shift;
    eval { $self->SUPER::write_result_set(@_); };
    if ($@) {
        unless ( $@ =~ /lock_store.al/ ) {
            die $@;
        }
        undef($@);
    }
}

package Socialtext::Search::CGI;

use base 'Socialtext::Query::CGI';
use Socialtext::CGI qw( cgi );

cgi search_term => '-html_clean';

######################################################################
package Socialtext::Search::Wafl;

use base 'Socialtext::Query::Wafl';
use Socialtext::l10n qw(loc);

sub _set_titles {
    my $self = shift;
    my $arguments = shift;
    my $title_info;
    if ( $self->target_workspace ne $self->current_workspace_name ) {
        $title_info = loc('Search for [_1] in workspace [_2]', $arguments, $self->target_workspace);
    } else {
        $title_info = loc('Search for [_1]', $arguments);
    }
    $self->wafl_query_title($title_info);
    $self->wafl_query_link($self->_set_query_link($arguments));
}

sub _set_query_link {
    my $self = shift;
    my $arguments = shift;
    return $self->hub->viewer->link_dictionary->format_link(
        link => 'search_query',
        workspace => $self->target_workspace,
        search_term => $self->uri_escape($arguments),
    );
}

sub _get_wafl_data {
    my $self = shift;
    my $hub            = shift;
    my $query          = shift;
    my $workspace_name = shift;
    my $main;

    $hub = $self->hub_for_workspace_name($workspace_name);

    $hub->search->get_result_set($query);
}

1;
