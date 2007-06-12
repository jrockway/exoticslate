#!perl -w
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext;
fixtures( 'admin_no_pages' );

plan skip_all => 'fetchrss accesses the network'
  unless $ENV{NLW_TEST_FETCHRSS} or $ENV{NLW_TEST_NETWORK};

plan tests => scalar blocks;

filters {
    wafl => ['format'],
    match => [qw(chomp regexp)],
};

my $hub = new_hub('admin');
my $viewer = $hub->viewer;

run_like wafl => 'match';

sub format {
    $viewer->text_to_html(shift)
}

__DATA__
=== cdent's movable type rss
--- wafl
{fetchrss http://www.burningchrome.com/~cdent/mt/index2.xml}
--- match
Glacial Erratics

=== cdent's again to test caching - note: doesn't actually check for caching, just that it doesn't blow up for some reason
--- wafl
{fetchrss http://www.burningchrome.com/~cdent/mt/index2.xml}
--- match
Glacial Erratics

=== html shouldn't parse
--- wafl
{fetchrss http://www.burningchrome.com/}
--- match
There was an error: Cannot detect

=== example.com shouldn't work either
--- wafl
{fetchrss http://www.example.com/wontwork}
--- match
There was an error: 404 Not Found

=== Atom wafl
--- wafl
{fetchatom http://news.google.com/news?q=iraq&output=atom}
--- match
iraq - Google News

=== Feed wafl
--- wafl
{feed http://www.burningchrome.com/~cdent/mt/index2.xml}
--- match
Glacial Erratics
