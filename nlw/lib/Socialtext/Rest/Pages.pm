package Socialtext::Rest::Pages;
# @COPYRIGHT@

use warnings;
use strict;

use base 'Socialtext::Rest::Collection';
use Socialtext;
use Socialtext::Workspace;
use Socialtext::HTTP ':codes';

use Socialtext::Page;
use Socialtext::Search 'search_on_behalf';
use Socialtext::String;

$JSON::UTF8 = 1;

# REVIEW: Why are we picking the first element in the results?
# In the earlier versions of this code, pages lists were generated
# with pages->all_ids_newest_first(), which had the most recently
# modified page at the top of the list. A collection's modified
# time is the most recently modified time of all the resources.
# The following code is no longer true, as we only sort by newest
# when query parameter order is set to newest, so we need to make
# a change here. One option is to traverse the list in this method,
# but we likely already did that somewhere else, so why do it again?
sub last_modified { 
    my $self = shift;
    my $r = shift;
    if (ref($r) eq 'ARRAY' and @$r) {
        return $r->[0]{modified_time};
    }
    return time;
}

# REVIEW: This need to be different depending on the query?
sub collection_name {
    'Pages from ' . $_[0]->workspace->title;
}

# REVIEW: 'pages/' is required here because we are not inside 'pages/'
# when this class responds. We are at pages, meaning we are inside the
# workspace. Using / on the end of the map in uri_map does not get
# the desired results, and are they even desired?
sub element_list_item {
    my ( $self, $page ) = @_;

    return "<li><a href='../$page->{workspace_name}/pages/$page->{uri}'>"
        . Socialtext::String::html_escape( $page->{name} )
        . "</a></li>\n";
}

=head2 POST

Create a new page, with the name of the page supplied by the
server. If creation is successful, return 201 and the Location:
of the new page

=cut

sub POST {
    my $self = shift;
    my ($rest) = @_;

    return $self->no_workspace() unless $self->workspace;
    return $self->not_authorized() unless $self->user_can('edit');

    # REVIEW: create_new_page does it's own auth checking but seems
    # to assume the "normal" interface. Or maybe we just need to
    # do some exception trapping, but we prefer our style for now.
    # If we make to this statement the call won't fail.
    my $page = $self->hub->pages->create_new_page();

    $page->update_from_remote(
        content => $rest->getContent(),
    );

    $rest->header(
        -status => HTTP_201_Created,
        -Location => $self->full_url('/', $page->uri),
    );
    return '';
}

sub _entity_hash {
    my $self   = shift;
    my $entity = shift;

    $entity->hash_representation();
}

# Generates an unordered, unsorted list of pages which satisfy the query
# parameters.
sub _entities_for_query {
    my $self = shift;

    # REVIEW: borrowing the 'q' name from google and others.  It's short.
    my $search_query = $self->rest->query->param('q');

    return defined $search_query
        ? $self->_searched_pages($search_query)
        : $self->hub->pages->all_active;
}

sub _searched_pages {
    my ( $self, $search_query ) = @_;

    map {
        Socialtext::Page->new(
            hub => $self->_hub_for_hit( $self->hub, $_->[0] ), id => $_->[1] )
        }
        map { [ $_->workspace_name, $_->page_uri ] }
        grep { $_->isa('Socialtext::Search::PageHit') } search_on_behalf(
            $self->hub->current_workspace->name,
            $search_query,
            undef,    # undefined scope
            $self->hub->current_user
        );
}

sub _hub_for_hit {
    # Mostly, evilly, stolen from Socialtext::Formatter::WaflPhrase
    my ( $self, $hub, $workspace_name ) = @_;
    if ( $workspace_name eq $hub->current_workspace->name ) {
        return $hub;
    }

    my $main = Socialtext->new();
    $main->load_hub(
        current_user      => $hub->current_user,
        current_workspace =>
            Socialtext::Workspace->new( name => $workspace_name ),
    );
    $main->hub->registry->load;
    return $main->hub;
}


1;
