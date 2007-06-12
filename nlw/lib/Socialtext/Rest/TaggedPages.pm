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
    "<li><a href='../../pages/$_[1]->{uri}'>"
        . Socialtext::String::html_escape( $_[1]->{name} )
        . "</a></li>\n";
}

# Generates an unordered, unsorted list of pages which satisfy the query
# parameters.
sub _entities_for_query {
    my $self = shift;

    return
        $self->hub->category->get_pages_for_category($self->tag);
}

sub allowed_methods {
    return 'GET, HEAD';
}

1;
