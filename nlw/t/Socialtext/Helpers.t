#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 8;
fixtures( 'admin' );

my $hub = new_hub('admin');

my $singapore = join '', map { chr($_) } 26032, 21152, 22369;
my $script_path = 'index.cgi';

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
