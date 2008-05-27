#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 6;
use Socialtext::Ceqlotron;

fixtures( 'admin_with_ordered_pages', 'foobar_with_ordered_pages' );

BEGIN {
    use_ok( "Socialtext::SearchPlugin" );
}

my $workspace_hub = new_hub('admin');

ceqlotron_run_synchronously();

run {
    my $case = shift;
    my $got = $workspace_hub->viewer->text_to_html($case->kwiki);
    smarter_like($got, $case->htmlre, $case->name);
};

__DATA__

=== {search title:page}
--- kwiki
{search title:page}
--- htmlre
action=search;search_term=title%3Apage
admin page five
admin page four
admin page three
admin page one
admin page two
admin page six

=== {search <foobar> title:page}
--- kwiki
{search <foobar> title:page}
--- htmlre
foobar/index.cgi\?action=search;search_term=title%3Apage
foobar page five
foobar page four
foobar page three
foobar page one
foobar page two
foobar page six

=== {search-full title:admin}
--- kwiki
{search-full title:admin}
--- htmlre
<!-- wiki: {include: \[admin page one\]} --></span>
<!-- wiki: {search_full: title:admin}
--></div><br /></div>

=== {search title:page workspaces:admin,foobar}
--- kwiki
{search title:page workspaces:admin,foobar}
--- htmlre
action=search;search_term=title%3Apage%20workspaces%3Aadmin%2Cfoobar
admin page five
admin page four
admin page three
admin page one
admin page two
admin page six
foobar page five
foobar page four
foobar page three
foobar page one
foobar page two
foobar page six

=== {search-full title:admin workspaces:admin,foobar}
--- kwiki
{search-full title:page workspaces:admin,foobar}
--- htmlre
<!-- wiki: {include: \[admin page one\]} --></span>
<!-- wiki: {include: foobar \[foobar page one\]} --></span>
<!-- wiki: {search_full: title:page workspaces:admin,foobar}
--></div><br /></div>

