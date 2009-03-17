#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 12;

###############################################################################
# Fixtures: clean admin
# - some of our tests expect a "clean" slate to start with, and count up the
#   number of items in the DB.
fixtures(qw( clean admin ));

my $hub = new_hub('admin');

my $singapore = join '', map { chr($_) } 26032, 21152, 22369;
my $script_path = 'index.cgi';

_get_workspace_list_for_template: {
    my $workspacelist=$hub->helpers->_get_workspace_list_for_template;
     
    is scalar(@$workspacelist), 2, 'length of workspace list';
    is_deeply $workspacelist,
        [
        { label => "Admin Wiki",               link => "/admin" },
        { label => "Socialtext Documentation", link => "/help-en" }
        ],
        "expected workspace list returned";
}

_get_history_list_for_template: {
    my $page_a = Socialtext::Page->new(hub => $hub, id => "quick_start",
        title => "Quick Start");
    my $page_b = Socialtext::Page->new(hub => $hub, id => "start_here",
        title => "Start Here");
    my $page_c = Socialtext::Page->new(hub => $hub, id => "people",
        title => "People");

    $hub->breadcrumbs->drop_crumb($page_a);
    $hub->breadcrumbs->drop_crumb($page_b);
    $hub->breadcrumbs->drop_crumb($page_c);
    my $historylist=$hub->helpers->_get_history_list_for_template;
    
    is scalar(@$historylist), 3, 'length of history list';
    my $page_base_uri = $hub->current_workspace->uri
        . Socialtext::AppConfig->script_name . "?";
    is_deeply $historylist,
        [
        { label => "People",      link => $page_base_uri . "people" },
        { label => "Start Here",  link => $page_base_uri . "start_here" },
        { label => "Quick Start", link => $page_base_uri . "quick_start" }
        ],
        "expected history list returned";
}


# Display page
{
    is
        $hub->helpers->page_display_link('quick_start'),
        qq(<a href="$script_path?quick_start">Quick Start</a>),
        'page_display_link';
}

# Edit page
{
    my $simple_page_name = 'a page';
    my $simple_params    = 'action=display;page_name=a%20page;js=show_edit_div';
    my $simple_path      = "$script_path?$simple_params";

    is $hub->helpers->page_edit_params($simple_page_name), $simple_params,
      'page_edit_params - simple input';

    is $hub->helpers->page_edit_path($simple_page_name), $simple_path,
      'page_edit_path - simple';

    is $hub->helpers->page_edit_link(
        $simple_page_name,
        'Edit simple page',
        'extra' => 1,
        'more'  => 2
      ),
      '<a href="' . $simple_path . ';extra=1;more=2">Edit simple page</a>',
      'page_edit_link - simple case';

    my $mangy      = qq[$singapore \\"hello&;];
    my $mangy_path =
        'index.cgi?action=display;page_name=%E6%96%B0%E5%8A%A0%E5%9D%A1%20%5C%22hello%26%3B;js=show_edit_div';

    is $hub->helpers->page_edit_path($mangy), $mangy_path,
      'page_edit_path - with gnarly input';

    is $hub->helpers->page_edit_link( $mangy, $mangy ),
       '<a href="'
       . $mangy_path
       . qq[">$singapore \\&quot;hello&amp;;</a>],
       'page_edit_link - gnarly input';
}

# script_link
is $hub->helpers->script_link('go', action => 'brownian', extra => 1),
    qq(<a href="$script_path?;action=brownian;extra=1">go</a>),
    'script_link';

# Preference
is $hub->helpers->preference_path('flavors', 'layout' => 'ugly'),
    "$script_path?action=preferences_settings;"
      . 'preferences_class_id=flavors;layout=ugly',
    'preferences_link'
