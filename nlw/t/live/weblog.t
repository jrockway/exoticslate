#!perl -w
# @COPYRIGHT@

use strict;
use warnings;

use Test::Live fixtures => ['admin'];
Test::Live->new->standard_query_validation;
__DATA__
=== Hit the settings page for Weblog Creation
--- query
action: weblogs_create
--- match: Create A Weblog

=== Create the Socialtext Blog
--- query
Button: Create
action: weblogs_create
weblog_title: Socialtext weblog
--- match
Weblog: Socialtext weblog
first post in Socialtext weblog.
by devnull1@socialtext.com on \w+ \d+ \d+:\d+[ap]m

=== Make sure weblog archive is displayed
--- query
action: weblog_display
category: Socialtext weblog
--- MATCH_WHOLE_PAGE
--- match
Loading...

=== Make sure we see the right content
--- query
action: weblog_html
--- match
<a href="index.cgi\?action=display;page_name=Navigation%20for%3A%20Socialtext%20weblog;js=show_edit_div;caller_action=weblog_display#edit">edit</a>

=== Hit TimeZone Settings Page
--- query
action: preferences_settings
preferences_class_id: timezone
--- match: How should displayed dates be formatted\?

=== Change date preferences
--- form: 2
--- post
timezone__timezone: -0600
timezone__dst: on
timezone__date_display_format: yyyy_mm_dd
timezone__time_display_12_24: 12
timezone__time_display_seconds: 1
Button: Button
--- match: value="yyyy_mm_dd" selected="selected"

=== Re-view the Socialtext weblog
--- query
action: weblog_display
category: Socialtext weblog
--- match
by devnull1\@socialtext.com on \d+-\d+-\d+ \d+:\d+:\d+[ap]m

=== Remove edit permission for workspace admin
--- do: removePermission workspace_admin edit

=== Create a blog without edit permissions, get redirected to to page of settings
--- query
Button: Create
action: weblogs_create
weblog_title: Some Random Blog
--- match
Change Password

=== Weblog with too long a catgeory name
--- query
action: weblog_html
category: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
--- match
Page title is too long; maximum length is
