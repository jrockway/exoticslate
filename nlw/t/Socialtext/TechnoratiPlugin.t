#!perl -w
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext;

# XXX with database outages at technorati, these tests
# fail. Need some way to test for good techno before
# running these tests (could do an LWP get of some kind
# perhaps.
plan skip_all => "technorati's database is sometimes flaky"
  unless $ENV{NLW_TEST_TECHNORATI}
  or $ENV{NLW_TEST_NETWORK};

plan tests => 7;

###############################################################################
# Fixture:  admin_no_pages
fixtures( 'admin_no_pages' );

###############################################################################
# TEST: error if we use a bad Technorati key
bad_technorati_key: {
    my $hub  = new_hub('admin');
    my $view = $hub->viewer();

    # over-ride the key
    no warnings 'redefine';
    local *Socialtext::TechnoratiPlugin::key = sub { 'foo' };

    # process the wafl
    my $url  = 'http://www.socialtext.com';
    my $wafl = "{technorati $url}\n";
    my $html = $view->text_to_html($wafl);

    # should contain an error
    like $html, qr/Bad technorati key/, 'error if bad technorati key';
}


###############################################################################
# TEST: ourselves, to make sure that we get a response with items
test_ourselves: {
    my $hub  = new_hub('admin');
    my $view = $hub->viewer();

    my $url  = 'http://www.socialtext.com';
    my $wafl = "{technorati $url}\n";
    my $html = $view->text_to_html($wafl);

    # should contain a few things in it...
    like $html, qr/Blog reactions to $url/, 'contains Technorati title';
    like $html, qr/"fetchrss_item"/, '... and at least one item';
}

###############################################################################
# TEST: ourselves (again), to test caching
test_ourselves_cached: {
    my $hub  = new_hub('admin');
    my $view = $hub->viewer();

    # over-ride FetchRSSPlugin, so it dies if we actually try to go out and
    # re-fetch the feed.  If we're using the cache, this should never get
    # called.
    no warnings 'redefine';
    local *Socialtext::FetchRSSPlugin::_get_content = sub { die "blech!" };

    # render the wafl
    my $url  = 'http://www.socialtext.com';
    my $wafl = "{technorati $url}\n";
    my $html = eval { $view->text_to_html($wafl) };

    # if we have _any_ results, we used the cache instead of re-fetching
    ok defined $html, 'used cached copy of RSS';
}

###############################################################################
# TEST: URL with a pound char in it
#
# NOTE: This test is sensitive to the URL used for the test; if the URL becomes
#       old/stale, the test may fail because Technorati returns no results for
#       it any longer.
url_with_pound_char: {
    my $hub = new_hub('admin');
    my $view = $hub->viewer();

    my $url  = 'http://alevin.com/weblog/archives/001567.html#001567';
    my $wafl = "{technorati $url}\n";
    my $html = $view->text_to_html($wafl);

    # should contain results
    like $html, qr/Blog reactions to $url/, 'title ok, when URL contains pound char';
    like $html, qr/Zero items/, "... but doesn't have any linked items right now";
}

###############################################################################
# TEST: should note an error if Technorati 404s on requesting the URL.
no_results_on_404: {
    my $hub = new_hub('admin');
    my $view = $hub->viewer();

    my $url  = 'http://www.example.com/wontwork';
    my $wafl = "{technorati $url}\n";
    my $html = $view->text_to_html($wafl);

    # empty results
    like $html, qr/Zero items/, 'no results, when technorati 404s the URL';
}
