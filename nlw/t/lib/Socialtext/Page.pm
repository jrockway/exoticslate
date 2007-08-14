package Socialtext::Page;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::MockBase';

sub uri {
    my $self = shift;
    return $self->{title};
}

sub to_html_or_default {
    my $self = shift;
    return $self->{html} || "$self->{title} Mock HTML";
}

sub name_to_id {
    my $self = shift;
    my $id = shift || '';
    return lc($id);
}

1;
