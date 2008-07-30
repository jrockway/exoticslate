package Socialtext::Model::Page;
# @COPYRIGHT@
use strict;
use warnings;
use DateTime::Format::Pg;
use Socialtext::SQL qw/sql_execute/;
use Socialtext::Page;
use Socialtext::File;
use Socialtext::URI;
use Socialtext::AppConfig;
use Carp qw/croak/;
use base 'Socialtext::Page::Base';

=head1 Socialtext::Model::Page

This class provides the same API as Socialtext::Page, but tries to be
lightweight and fast.  Users shouldn't call new_from_row(), but should
instead be given objects via Socialtext::Model::Pages.

=cut

my $SCRIPT_NAME = Socialtext::AppConfig->script_name();

# Called only by Socialtext::Model::Pages
sub new_from_row {
    my $class = shift;
    my $db_row = shift;
    bless $db_row, $class;
    return $db_row;
}

# This is called by Socialtext::Query::Plugin::push_result
# to create a row suitable for display in a listview.
sub to_result {
    my $self = shift;

    my $result = {
        From     => $self->{last_editor_username},
        username => $self->{last_editor_username},
        Date     => $self->{last_edit_time},
        DateLocal => $self->datetime_for_user,
        Subject  => $self->{name},
        Revision => $self->{current_revision_num},
        Summary  => $self->{summary},
        Type     => $self->{page_type},
        page_id  => $self->{page_id},
        page_uri => $self->uri,
        revision_count => $self->{revision_count},
    };

    return $result;
}

sub datetime_for_user {
    my $self = shift;
    my $datetime = $self->{last_edit_time};
    if ($self->{hub}) {
        $datetime = $self->{hub}->timezone->date_local($datetime);
    }
    return $datetime;
}

sub title          { $_[0]->{name} }
sub id             { $_[0]->{page_id} }
sub uri            { $_[0]->{page_id} }
sub summary        { $_[0]->{summary} }
sub deleted        { $_[0]->{deleted} }
sub last_edit_time { $_[0]->{last_edit_time} }
sub add_tag        { push @{ shift->{tags} }, @_ }
sub hub            { $_[0]->{hub} || die "No hub was given to the page object"}
sub is_spreadsheet { $_[0]->{page_type} eq 'spreadsheet' }
sub current_revision_num { $_[0]->{current_revision_num} }
sub revision_count { $_[0]->{revision_count} }

sub tags {
    my $self = shift;
    unless ($self->{tags}) {
        die "tags not loaded, and lazy loading is not yet supported.";
    }
    return $self->{tags};
}

sub hash_representation {
    my $self = shift;

    my $hash = {
        name           => $self->{name},
        uri            => $self->{page_id},
        page_id        => $self->{page_id},
        last_editor    => $self->{last_editor_username},
        last_edit_time => $self->{last_edit_time},
        revision_id    => $self->{current_revision_id},
        revision_count => $self->{revision_count},
        workspace_name => $self->{workspace_name},
        type           => $self->{page_type},
        tags           => $self->{tags},
        page_uri       => $self->full_uri,
        modified_time  => $self->modified_time,
    };
    return $hash;
}

sub modified_time {
    my $self = shift;
    return $self->{modified_time} ||= 
        DateTime::Format::Pg->parse_timestamptz($self->{last_edit_time})->epoch;
}


sub workspace {
    my $self = shift;
    return $self->{workspace} ||= Socialtext::Workspace->new(
        workspace_id => $self->{workspace_id},
    );
}

sub full_uri {
    my $self = shift;
    return Socialtext::URI::uri(
        path => "$self->{workspace_name}/",
    ) . "$SCRIPT_NAME?$self->{page_id}";
}

sub categories_sorted {
    my $self = shift;
    return sort {lc($a) cmp lc($b)} @{$self->{tags}};
}

sub last_edited_by {
    my $self = shift;
    return $self->{last_editor}
        ||= Socialtext::User->new( user_id => $self->{last_editor_id} );
}

sub creator {
    my $self = shift;
    return $self->{creator}
        ||= Socialtext::User->new( user_id => $self->{creator_id} );
}

# Content is still read from disk
sub content {
    my $self = shift;
    my $file = $self->current_revision_file;
    my $data = Socialtext::File::get_contents_utf8($file);
    my $body = substr($data, index($data, "\n\n") + 2);
    return $body;
}

sub current_revision_file {
    my $self = shift;
    my $revision_id = $self->{current_revision_id};
    return $self->directory_path . "/$revision_id.txt";
}

# This is the on-disk directory pages are stored, nothing to do with
# Postgresql
sub database_directory {
    my $self = shift;
    return Socialtext::Paths::page_data_directory( $self->{workspace_name} );

}

sub store {
    die 'Socialtext::Model::Page is currently a READ ONLY object';
}

1;
