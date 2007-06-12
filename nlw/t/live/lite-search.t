#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Live fixtures => ['admin'];
Test::Live->new()->standard_query_validation;
# XXX I hate the live tests, but need the live tests
# Ideally some of these would be doing dom checks, not string matches
__END__
=== Hit a non-existent page
--- do: cleanCeqlotron
--- request_path: /lite/page/admin/Righteousness?action=edit
--- match
method="post"
action="/lite/page/admin/Righteousness"

=== Make an edit
--- form: editform
--- post
page_body: inconceivable this stuff
--- match
        <div class="wiki">
<p>
inconceivable this stuff</p>
</div>

=== Get the search page
--- request_path: /lite/search/admin
--- match
method="get"
action="/lite/search/admin"

=== Do a search
--- do: runCeqlotron
--- request_path: /lite/search/admin?search_term=title:righteousness
--- match
href="/lite/page/admin/righteousness">Righteousness</a>

