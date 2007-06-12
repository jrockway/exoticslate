#!perl
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 4;
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
admin page six
admin page five
admin page four
admin page three
admin page two
admin page one

=== {search <foobar> title:page}
--- kwiki
{search <foobar> title:page}
--- htmlre
foobar/index.cgi\?action=search;search_term=title%3Apage
foobar page six
foobar page five
foobar page four
foobar page three
foobar page two
foobar page one

=== {search-full title:admin}
--- kwiki
{search-full title:admin}
--- htmlre
<!-- wiki: {include: \[admin page one\]} --></span>
<!-- wiki: {search_full: title:admin} --></div><br /></div>
