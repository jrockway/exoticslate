# @COPYRIGHT@
package Socialtext::Query::Plugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use Class::Field qw( const field );
use Storable ();

# XXX Rather than doing all this sortdir crap and the related
# caching, we should get javascript sortable tables in there.
# The question to answer with that, though, is if we would
# need to degrade well in a non javascript situation?
const sortdir => {
    Summary        => 1,
    Subject        => 0,
    From           => 0,
    Date           => 0,
    revision_count => 1,
};

const listview_extra_columns => {};

field result_set =>
      -init => '$self->read_result_set';

field 'error_message';

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
    my $metadata = $page->metadata;
    my $result;
    $result->{$_} = $metadata->$_
      for qw(From Date Subject Revision Summary Type);
    $result->{DateLocal} = $page->datetime_for_user;
    $result->{revision_count} = $page->revision_count;
    $result->{page_uri} = $page->uri;
    $result->{page_id} = $page->id;
    $result->{From} =
        $page->last_edited_by->best_full_name( workspace => $self->hub->current_workspace );
    $result->{username} =
        $page->last_edited_by->username;

    push @{$self->result_set->{rows}}, $result;
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

# XXX when we send a result set to the template
# perhaps it could be just a list of pages. This
# presents difficulties with the attachments that
# are found for search results.
sub display_results {
    my $self = shift;
    my $sortdir = shift;

    $self->screen_template('view/listview');

    my $result_set = $self->result_set;
    $self->result_set(undef);
    $self->render_screen(
        %$result_set,
        sortdir => $sortdir,
        error_message => $self->error_message,
        listview_extra_columns => $self->listview_extra_columns,
        @_,
    );
}

sub sorted_result_set {
    my $self = shift;
    my $sortdir_map = shift;
    my $limit = shift;

    my $sortby = $self->cgi->sortby || 'Date';

    my $direction = length $self->cgi->direction
      ? $self->cgi->direction ? 1 : 0
      : $sortdir_map->{$sortby};

    my $sortsub
        = $self->_gen_sort_closure( $sortdir_map, $sortby, $direction );

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
    my $sortdir_map = shift;
    my $sortby      = shift;
    my $direction   = shift;

    $sortdir_map->{$sortby} = 1 - $direction;
    return $sortby eq 'revision_count'
      ? $direction
        ? sub { $b->{$sortby} <=> $a->{$sortby} or
                lc($a->{Subject}) cmp lc($b->{Subject}) }
        : sub { $a->{$sortby} <=> $b->{$sortby} or
                lc($a->{Subject}) cmp lc($b->{Subject}) }
      : $direction
        ? sub { lc($b->{$sortby}) cmp lc($a->{$sortby}) or
                lc($a->{Subject}) cmp lc($b->{Subject}) }
        : sub { lc($a->{$sortby}) cmp lc($b->{$sortby}) or
                lc($a->{Subject}) cmp lc($b->{Subject}) }
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

1;
