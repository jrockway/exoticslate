# @COPYRIGHT@
package Socialtext::WeblogArchive;
use strict;
use warnings;

use base 'Socialtext::WeblogPlugin';

use Class::Field qw( const );

sub class_id { 'weblog_archive' }
const class_title => 'Weblog Archives';
const maximum_entries => 10_000;

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(action => 'weblog_archive_html');
}

sub weblog_archive_html {
    my $self = shift;
    my $blog_category = shift;
    $blog_category ||= $self->current_blog;
    my $archive = $self->assemble_archive($blog_category);

    $self->template_process(
        'weblog_archive_box_filled.html',
        archive  => $archive,
        category => $self->current_blog_escape_uri,
    );
}

sub assemble_archive {
    my $self = shift;
    my $blog_category = shift;

    my $entries = $self->_get_entries_faster($blog_category);

    my %archive;
    my $by_create = $self->hub->current_workspace->sort_weblogs_by_create;
    foreach my $entry_number (0 .. $#{$entries}) {
        my $entry = $entries->[$entry_number];
        my $date  =   $by_create
                    ? $self->get_date_of_create($entry)
                    : $self->get_date_of_update($entry);
        my $month = $archive{$date->{year}}->{$date->{month}} ||= {};
        $month->{name}  ||= $date->{month_name};
        $month->{start} = $entry_number if not defined $month->{start};
        $month->{limit}++;
    }
    return \%archive;
}

sub _get_entries_faster {
    my ($self, $blog) = @_;
    my @pages = $self->hub->category->get_pages_numeric_range(
        $blog, 0, $self->maximum_entries,
        ( $self->hub->current_workspace->sort_weblogs_by_create ? 'create' : 'update' ),
    );
    my @entries;
    for my $page (@pages) {
        push @entries, {
            raw_date    => (split /\s+/, $page->metadata->Date)[0],
            revision_id => $page->revision_id,
        }
    }
    return \@entries;
}

sub get_date_of_update {
    my $self = shift;
    my $entry = shift;
    my ($year, $month) = split /-/, $entry->{raw_date};
    return $self->_date($year, $month);
}

sub get_date_of_create {
    my $self = shift;
    my $entry = shift;
    my ($year, $month) = ($entry->{revision_id} =~ /^(\d{4})(\d{2})/);
    return $self->_date($year, $month);
}

sub _date {
    my ($self, $year, $month) = @_;
    my @month_names = qw[
        January February March
        April   May      June
        July    August   September
        October November December
    ];
    $month =~ s/^0//;
    my $date = {
        year       => $year,
        month      => $month,
        month_name => $month_names[$month - 1],
    };
    return $date;
}

sub box_title { 'Weblog Archive' }

1;
