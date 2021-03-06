#!perl -w
# @COPYRIGHT@

use strict;
use warnings;
use Test::Socialtext tests => 7;

###############################################################################
###############################################################################
### Due to Technorati being somewhat flaky, all of these tests have SKIP
### blocks in case the test runs at a point that Technorati gives bogus/wonky
### responses.
###############################################################################
###############################################################################

###############################################################################
# Fixture:  admin
fixtures( 'admin' );

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
    SKIP: {
        skip 'Technorati is flaky', 2, if ($html =~ /invalid response/);
        like $html, qr/Blog reactions to $url/, 'contains Technorati title';
        like $html, qr/"fetchrss_item"/, '... and at least one item';
    }
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
    SKIP: {
        skip 'Technorati is flaky', 2, if ($html =~ /invalid response/);
        like $html, qr/Blog reactions to $url/, 'title ok, when URL contains pound char';
        like $html, qr/Zero items/, "... but doesn't have any linked items right now";
    }
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
    SKIP: {
        skip 'Technorati is flaky', 1, if ($html =~ /invalid response/);
        like $html, qr/Zero items/, 'no results, when technorati 404s the URL';
    }
}
