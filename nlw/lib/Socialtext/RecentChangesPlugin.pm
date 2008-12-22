# @COPYRIGHT@
package Socialtext::RecentChangesPlugin;
use Socialtext::CategoryPlugin;
use Socialtext::l10n qw/loc/;
use Socialtext::Timer;
use Socialtext::Model::Pages;
use strict;
use warnings;

use base 'Socialtext::Query::Plugin';

use Class::Field qw( const );
use Socialtext::l10n qw ( loc );

sub class_id { 'recent_changes' }
const class_title      => loc("What's New");
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
    $p->query(loc('What time interval should "What\'s New" display?'));
    $p->type('pulldown');
    my $choices = [
        1 => loc('Last 24 hours'),
        2 => loc('Last 2 Days'),
        3 => loc('Last 3 Days'),
        7 => loc('Last Week'),
        14 => loc('Last 2 Weeks'),
        31 => loc('Last Month'),
    ];
    $p->choices($choices);
    $p->default(7);
    return $p;
}

sub sidebox_changes_depth {
    my $self = shift;
    my $p = $self->new_preference('sidebox_changes_depth');
    $p->query(loc('How many items from that time period should be displayed as a side box on pages?'));
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
    $p->query(loc('Display as a side box in page view?'));
    $p->type('boolean');
    $p->default(0);
    return $p;
}


*changes = \&recent_changes;
sub recent_changes {
    my $self = shift;

    if ( $self->cgi->changes =~ /\// ) {
        Socialtext::Exception::DataValidation->throw(
            errors => [loc("Invalid character '/' in changes parameter")] );
    }

    my $type = $self->cgi->changes;
    my $sortdir = $self->sortdir;

    Socialtext::Timer->Continue('get_result_set');

    $self->dont_use_cached_result_set();
    #$self->default_result_set();
    $self->result_set( $self->sorted_result_set( $sortdir ) );
    if ($type eq 'all') {
        $self->result_set->{predicate} = "action=changes;changes=all";
    }

    Socialtext::Timer->Pause('get_result_set');

    $self->display_results(
        $sortdir,
        miki_url      => $self->hub->helpers->miki_path('recent_changes_query'),
        feeds         => $self->_feeds( $self->hub->current_workspace ),
        unplug_uri    => "?action=unplug",
        unplug_phrase => loc('Click this button to save the [_1] most recent pages to your computer for offline use.', $self->hub->tiddly->default_count),
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


sub recent_changes_html {
    my $self = shift;
    my $count = $self->preferences->sidebox_changes_depth->value;
    Socialtext::Timer->Continue('get_recent_changes');
    my $changes = $self->get_recent_changes($count);
    Socialtext::Timer->Pause('get_recent_changes');
    $self->template_process('recent_changes_box_filled.html',
        %$changes,
    );
}

sub get_recent_changes {
    my $self = shift;
    my $count = shift;
    return $self->get_recent_changes_in_category(
        count    => $count,
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
    my $count = $p{count};
    my $category = $p{category};

    Socialtext::Timer->Continue('RCP_new_changes');
    $self->result_set($self->new_result_set($type));

    my $display_title;
    my $pages_ref;
    if (defined $type && $type eq 'all') {
        $display_title = loc("All Pages");
        $pages_ref = Socialtext::Model::Pages->All_active(
            hub => $self->hub,
            workspace_id => $self->hub->current_workspace->workspace_id,
        );
    }
    else {
        my $depth = $self->preferences->changes_depth;
        my $last_changes_time = loc($depth->value_label);
        $display_title = loc('Changes in [_1]', $last_changes_time);

        $pages_ref = $self->by_seconds_limit(
            $category ? ( tag => $category ) : (),
            count => $count,
        );
    }

    Socialtext::Timer->Continue('new_changes_push_result');
    for my $page (@$pages_ref) {
        $self->push_result($page);
    }
    Socialtext::Timer->Pause('new_changes_push_result');

    my $hits = $self->result_set->{hits} = @{$self->result_set->{rows}};
    $self->result_set->{display_title} = "$display_title ($hits)";
    Socialtext::Timer->Pause('RCP_new_changes');
}

sub by_seconds_limit {
    my $self = shift;
    my %args = @_;

    my $prefs = $self->hub->recent_changes->preferences;
    my $seconds = $prefs->changes_depth->value * 1440 * 60;
    my $pages = Socialtext::Model::Pages->By_seconds_limit(
        seconds          => $seconds,
        hub              => $self->hub,
        workspace_id     => $self->hub->current_workspace->workspace_id,
        count            => $self->preferences->sidebox_changes_depth->value,
        do_not_need_tags => 1,
        %args,
    );
    return $pages;
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
    $self->new_changes( type => $self->cgi->changes || '' );
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
use Socialtext::l10n qw/loc/;

sub _set_titles {
    my $self = shift;
    my $title_info;;
    if ($self->target_workspace ne $self->current_workspace_name) {
        $title_info = loc("What\'s New in workspace [_1]", $self->target_workspace);
    } else {
        $title_info = loc("What\'s New");
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

