package Socialtext::Page;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::MockBase';
use unmocked 'Data::Dumper';
use unmocked 'Class::Field', 'field', 'const';

field 'name';
field 'id', -init => '$self->name';
field 'uri', -init => '$self->id';

const _MAX_PAGE_ID_LENGTH => 255;

sub title { $_[0]->{title} || $_[0]->name || 'Mock page title' }

sub to_html_or_default {
    my $self = shift;
    return $self->{html} || ($self->title . " Mock HTML");
}

sub to_absolute_html {
    my $self = shift;
    return $self->{absolute_html} || "$self->{page_id} Absolute HTML";
}

sub to_html {
    my $self = shift;
    return $self->{html} || "$self->{page_id} HTML";
}

sub preview_text { 'preview text' }

sub directory_path { '/directory/path' }

sub load {} 
sub exists {}
sub loaded { 1 }
sub update { }
sub store {}

sub hub { $_[0]->{hub} || Socialtext::Hub->new }

sub revision_count { $_[0]->{revision_count} || 1 }
sub revision_id { $_[0]->{revision_id} || 1 }

sub content { $_[0]->{content} || 'Mock page content' }

sub add_tags {
    my $self = shift;
    push @{ $self->{tags} }, @_;
}

# Metadata
sub metadata { shift } # hack - return ourself
sub Subject { $_[0]->{title} }
sub Type { $_[0]->{type} || 'page' }
sub Revision { $_[0]{revision} || 'page_rev' }
sub Category { $_[0]{category} || $_[0]{tags} || ['mock_category'] }

sub original_revision { shift } # hack - return ourself
sub datetime_for_user { 'Mon 12 12:00am' }
sub last_edited_by { Socialtext::User->new(username => 'mocked_user') }
sub edit_summary { 'awesome' }

1;
