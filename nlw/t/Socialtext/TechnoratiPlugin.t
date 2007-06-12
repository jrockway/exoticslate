#!perl -w
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext;
fixtures( 'admin_no_pages' );

# XXX with database outages at technorati, these tests
# fail. Need some way to test for good techno before
# running these tests (could do an LWP get of some kind
# perhaps.

plan skip_all => "technorati's database is sometimes flaky"
  unless $ENV{NLW_TEST_TECHNORATI}
  or $ENV{NLW_TEST_NETWORK};

plan tests => scalar blocks;

my $hub = new_hub('admin');
my $viewer = $hub->viewer;

run {
    my $block = shift;
    my $wafl = $block->wafl;
    my $match = $block->match;
    local *Socialtext::TechnoratiPlugin::key = \&Socialtext::TechnoratiPlugin::key;
    if ($block->use_key) {
        no warnings 'redefine';
        *Socialtext::TechnoratiPlugin::key = sub { $block->use_key };
    }
    my $actual = $viewer->text_to_html($wafl);
    like $actual, $match, $block->name;
};

__DATA__
=== should error on bad key
--- use_key chomp
foo
--- wafl
{technorati http://www.socialtext.com}
--- match regexp
Bad technorati key

=== www.socialtext.com
--- wafl
{technorati http://www.socialtext.com}
--- match literal_lines_regexp
Technorati links to http://www.socialtext.com
fetchrss_item
fetchrss_item
fetchrss_item

=== www.socialtext.com, again, to test caching
--- wafl
{technorati http://www.socialtext.com}
--- match literal_lines_regexp
Technorati links to http://www.socialtext.com
fetchrss_item
fetchrss_item
fetchrss_item

=== url with pound char in it
--- wafl
{technorati: http://alevin.com/weblog/archives/001567.html#001567}
--- match regexp
BookBlog

=== should error on 404
--- wafl
{technorati http://www.example.com/wontwork}
--- match regexp
Zero items

