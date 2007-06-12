#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Live fixtures => ['admin'];
use Readonly;

Readonly my @STATIC_FILES => (qw( css/st/screen.css javascript/combined-source.js ));

my $live_tester = Test::Live->new;
$live_tester->standard_query_validation;

{
    $live_tester->log_in;
    $live_tester->static_sums_match($_)
        foreach @STATIC_FILES;
}

__END__
=== blog page <link>s to CSS files
--- query
action: weblog_display
--- MATCH_WHOLE_PAGE
--- match
<link rel="stylesheet" type="text/css" href="/static/.*?/css/st/screen.css"
