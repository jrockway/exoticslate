# @COPYRIGHT@
package Socialtext::RecentChangesPlugin;
use Socialtext::CategoryPlugin;
use strict;
use warnings;

use base 'Socialtext::Query::Plugin';

use Class::Field qw( const );


sub class_id { 'recent_changes' }
const class_title      => "What's New";
const cgi_class        => 'Socialtext::RecentChanges::CGI';
const default_category => 'recent changes';

sub register {
    my $self = shift;
    $self->SUPER::register(@_);
    my $registry = shift;
    $registry->add(action => 'changes'); # used for displaying all
    $registry->add(action => 'recent_changes_html');
    $registry->add(preference => $self->changes_depth);
    $registry->add(preference => $self->include_in_pages);
    $registry->add(preference => $self->sidebox_changes_depth);
    $registry->add(wafl => 'recent_changes' => 'Socialtext::RecentChanges::Wafl' );
    $registry->add(
        wafl => 'recent_changes_full' => 'Socialtext::RecentChanges::Wafl' );
}

sub get_result_set_path {
    my $self = shift;
    my $extension = $self->cgi->changes || '';
    return $self->SUPER::get_result_set_path(@_) . $extension;
}

sub changes_depth {
    my $self = shift;
    my $p = $self->new_preference('changes_depth');
    $p->query('What time interval should "What\'s New" display?');
    $p->type('pulldown');
    my $choices = [
        1 => 'Last 24 hours',
        2 => 'Last 2 Days',
        3 => 'Last 3 Days',
        7 => 'Last Week',
        14 => 'Last 2 Weeks',
        31 => 'Last Month',
    ];
    $p->choices($choices);
    $p->default(7);
    return $p;
}

sub sidebox_changes_depth {
    my $self = shift;
    my $p = $self->new_preference('sidebox_changes_depth');
    $p->query('How many items from that time period should be displayed as a side box on pages?');
    $p->type('pulldown');
    my $choices = [
        2 => 2, 4 => 4, 6 => 6, 8 => 8, 10 => 10, 15 => 15, 20 => 20
    ];
    $p->choices($choices);
    $p->default(4);
    return $p;
}

sub include_in_pages {
    my $self = shift;
    my $p = $self->new_preference('include_in_pages');
    $p->query('Display as a side box in page view?');
    $p->type('boolean');
    $p->default(0);
    return $p;
}

sub recent_changes {
    my $self = shift;

    if ( $self->cgi->changes =~ /\// ) {
        Socialtext::Exception::DataValidation->throw(
            errors => ["Invalid character '/' in changes parameter"] );
    }

    my $type = $self->cgi->changes;
    my %sortdir = %{$self->sortdir};

    # if we call sorted_result_set with an unset result_set the
    # cached version will be magically read
    if ($self->cgi->sortby) {
        $self->result_set( $self->sorted_result_set( \%sortdir ) );
    }
    else {
        $self->new_changes(
            type => $type,
        );

        if ($type eq 'all') {
            $sortdir{Date} = 1;
            $self->result_set( $self->sorted_result_set( \%sortdir ) );
            $self->result_set->{predicate} = "action=changes;changes=all";
        }
        $self->write_result_set;
    }

    $self->display_results(
        \%sortdir,
        feeds         => $self->_feeds( $self->hub->current_workspace ),
        unplug_uri    => "?action=unplug",
        unplug_phrase => 'Click this button to save the '
            . $self->hub->tiddly->default_count
            . ' most recent pages to your computer for offline use.',
    );
}

sub _feeds {
    my $self = shift;
    my $workspace = shift;

    my $feeds = $self->SUPER::_feeds($workspace);
    $feeds->{rss}->{page} = {
        title => $feeds->{rss}->{changes}->{title},
        url => $feeds->{rss}->{changes}->{url},
    };
    $feeds->{atom}->{page} = {
        title => $feeds->{atom}->{changes}->{title},
        url => $feeds->{atom}->{changes}->{url},
    };

    return $feeds;
}

# XXX this little thing is ugly.
*changes = \&recent_changes;

sub recent_changes_html {
    my $self = shift;
    my $count = $self->preferences->sidebox_changes_depth->value;
    my $changes = $self->get_recent_changes($count);
    $self->template_process('recent_changes_box_filled.html',
        %$changes,
    );
}

sub get_recent_changes {
    my $self = shift;
    my $count = shift;
    return $self->get_recent_changes_in_category(
        count    => $count,
        category => $self->default_category,
    );
}

sub get_recent_changes_in_category {
    my $self = shift;
    my %p = @_;
    $self->new_changes( %p );
    return $self->result_set;
}

sub new_changes {
    my $self = shift;
    my %p = @_;
    my $type = $p{type} || '';
    my $category = $p{category} || $self->default_category;

    $self->result_set($self->new_result_set($type));

    my $display_title;
    my $pages_ref;
    if (defined $type && $type eq 'all') {
        $display_title = "All Pages";
        $pages_ref = [$self->hub->pages->all_active];
    }
    else {
        my $depth = $self->preferences->changes_depth;
        $display_title = 'Changes in ' . $depth->value_label;
        my $days = $depth->value;
        my $minutes = $days * 1440;
        $pages_ref =
            $self->hub->category->get_pages_by_seconds_limit(
                $category,
                $minutes * 60,
                $p{count},
            );
    }

    for my $page (@$pages_ref) {
        $self->push_result($page);
    }

    my $hits = $self->result_set->{hits} =
      @{$self->result_set->{rows}};
    $self->result_set->{display_title} = "$display_title ($hits)";
}

sub new_result_set {
    my $self = shift;
    my $type = shift || '';
    return +{
        rows => [],
        hits => 0,
        display_title => '',
        predicate => 'action=' . $self->class_id . ';changes=' . $type,
    }
}

sub default_result_set {
    my $self = shift;
    $self->new_changes;
    return $self->result_set;
}

######################################################################
package Socialtext::RecentChanges::CGI;

use base 'Socialtext::Query::CGI';
use Socialtext::CGI qw( cgi );

cgi 'changes';

######################################################################
package Socialtext::RecentChanges::Wafl;

use Socialtext::CategoryPlugin;
use base 'Socialtext::Category::Wafl';

sub _set_titles {
    my $self = shift;
    my $title_info = "What's New";
    if ($self->target_workspace ne $self->current_workspace_name) {
        $title_info .= ' in workspace ' . $self->target_workspace;
    }
    $self->wafl_query_title($title_info);
    $self->wafl_query_link($self->_set_query_link);
}

sub _set_query_link {
    my $self = shift;
    my $arguments = shift;
    return $self->hub->viewer->link_dictionary->format_link(
        link => 'recent_changes_query',
        workspace => $self->target_workspace,
    );
}

sub _parse_arguments {
    my $self = shift;
    my $arguments = shift;

    $arguments =~ s/^\s*<//;
    $arguments =~ s/>\s*$//;

    my $workspace_name = $arguments;
    $workspace_name = $self->current_workspace_name unless $workspace_name;
    return ( $workspace_name, undef );
}

1;

