package Socialtext::Page;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::MockBase';
use unmocked 'Data::Dumper';
use unmocked 'Class::Field', 'field';

field 'name';

sub uri {
    my $self = shift;
    return $self->{title};
}

sub to_html_or_default {
    my $self = shift;
    return $self->{html} || "$self->{title} Mock HTML";
}

sub to_absolute_html {
    my $self = shift;
    return $self->{absolute_html} || "$self->{page_id} Absolute HTML";
}

sub to_html {
    my $self = shift;
    return $self->{html} || "$self->{page_id} HTML";
}

sub name_to_id {
    my $self = shift;
    my $id = shift || '';
    return lc($id);
}

sub preview_text { 'preview text' }

sub directory_path { '/directory/path' }

1;
