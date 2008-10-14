#!perl
# @COPYRIGHT@

use warnings;
use strict;

use Test::Socialtext tests => 40;
fixtures( 'admin' );

use Socialtext::Page ();
use Socialtext::Ceqlotron ();

BEGIN {
    use_ok("Socialtext::Lite");
}

Socialtext::Ceqlotron::clean_queue_directory();

my $Singapore = join '', map { chr($_) } 26032, 21152, 22369;

# Sleep a bit, after setting up our test fixtures
#
# Some of our tests below require that edits that we do trigger the page to go
# to the top of the "recent changes" list.  Granularity for "last edit time"
# in the DB is "to the second", so we need to sleep a bit to make sure that
# our edits are going to be recorded at a different moment in time than the
# initial fixture creation.
sleep 1;

# create an object and check its health
my $hub = new_hub('admin');
isa_ok( $hub, 'Socialtext::Hub' );

my $lite = Socialtext::Lite->new( hub => $hub );
isa_ok( $lite, 'Socialtext::Lite' );
is( $lite->hub, $hub, 'Socialtext::Lite object holds the hub we gave it' );

# create a page and dislay it
my $page = Socialtext::Page->new( hub => $hub )->create(
    title   => 'we are the world',
    content => <<'EOF',
we are the children

except that we're not
EOF
    creator => $hub->current_user,
);
isa_ok( $page, 'Socialtext::Page' );

my $html = $lite->display($page);

# okay here we go with stupid regular expressions again
like(
    $html, qr{\Q<title>Admin Wiki : we are the world</title>},
    'page display has correct title'
);
like(
    $html,
    qr{<div class="wiki".*we are the children.*except that we&#39;re not}sm,
    'page display includes correct content'
);
like(
    $html, qr{<a href="/nlw/submit/logout\?redirect_to=[^"]+">Log out</a>},
    'page display includes log out button'
);

# request edit screen for existing page
$html = $lite->edit_action($page);

like( $html, qr{\Q<title>Admin Wiki : Edit we are the world</title>},
    'edit form has the correct title' );
like( $html, qr{\Qaction="/lite/page/admin/we_are_the_world"},
    'edit form action goes to correct page' );
like( $html, qr{<textarea.*we are the children.*except that we're not}sm,
    'edit form contains correct page content' );

# request edit screen for non-existent page
my $incipient_page = $hub->pages->new_from_name('Stronger Than Dust?');
isa_ok( $incipient_page, 'Socialtext::Page' );
$html = $lite->edit_action($incipient_page);

like( $html, qr{\Q<title>Admin Wiki : Edit Stronger Than Dust?</title>},
    'edit form has correct title for incipient page' );
like( $html, qr{\Qaction="/lite/page/admin/Stronger%20Than%20Dust%3F"},
    'edit form action goes to correct page' );
like( $html, qr{<textarea[^>]+></textarea>},
    'edit form contains no content' );

# edit the page
my $new_content =<<"EOF";
My goodness, that sure is a page

[A Link]

Singapore link [$Singapore]

{category help}

{weblog help}
EOF

eval {
    $lite->edit_save(
        page    => $incipient_page,
        content => $new_content,
        subject => 'Stronger Than Dust?',
    );
};

ok( !$@, "no errors from edit_save: $@" );
my $new_page = $hub->pages->new_from_name('Stronger Than Dust?');
isa_ok( $new_page, 'Socialtext::Page' );
my $title    = $new_page->title;
my $content  = $new_page->content;

is( $title, 'Stronger Than Dust?', 'new page has correct title' );
is( $content, $new_content, 'page has correct body' );

$html = $lite->display($new_page);

# FIXME this test is bogus, the provided data is not encoded
# as it would be if coming from apache, I think...
like( $html,
    qr{Singapore link <a href="[^"]*page_name=%E6%96%B0%E5%8A%A0%E5%9D%A1".*>$Singapore</a>},
    'funkity characters remain sane through input' );

like( $html, qr{\Qtitle="category link" href="/lite/category/admin/help">help</a>},
    'category link links right place' );
like( $html, qr{\Qtitle="weblog link" href="/lite/changes/admin/help">help</a>},
    'weblog link links right place' );

# exercise contention handling
eval {
    $html = $lite->edit_save(
        page        => $new_page,
        content     => "collide with me\n\n.html\n<h1>Ho</h1>\n.html\n\n",
        revision_id => $new_page->revision_id - 1,
        revision    => '',
        subject     => $new_page->title,
    );
};
ok( !$@, "no errors from edit_save: $@" );
like( $html,
    qr{\Q<title>Admin Wiki : Stronger Than Dust? Editing Error</title>},
    'contention page is returned' );
like( $html,
    qr{<pre>.*collide with me.*}ms,
    'content of contention info is right' );
like( $html,
    qr{\Q<a href="/lite/page/admin/stronger_than_dust?action=edit">Edit},
    'edit link is displayed' );
like( $html,
    qr{<pre>.*&lt;h1&gt;Ho&lt;/h1&gt;.*</pre>}ms,
    'html in contention section is html escaped' );

# see that page in recent changes
$html = $lite->recent_changes();

# XXX workspace titles are stupid in test environments but presumably
# fixed on the workspaces in databases branch, the following would
# normalling be 'Admin Wiki Recent Changes' but the test env has it
# be what's shown
like( $html, qr{\Q<title>Admin Wiki : Recent Changes</title>},
    'recent changes page has correct title' );
like( $html, qr{<ul>\s+<li>\s+<a title="Stronger Than Dust\?"},
    'most recently changed page is the most recently listed page' );

# get the search page
$html = $lite->search();
like( $html, qr{\Q<input name="search_term" value="" />},
    'search form presents when no query' );

# index the content we created
ceqlotron_run_synchronously();

# do a word search
$html = $lite->search('title:dust');
like( $html, qr{\Q<input name="search_term" value="title:dust" />},
    'search form presents with search_term' );
like( $html, qr{<li>.*<a.*href="/lite/page/admin/stronger_than_dust"}ms, 
    'search results include expected page' );

## investigate category handling
# get the category list
$html = $lite->category();

like( $html, qr{\Q<title>Admin Wiki : Categories</title>},
    'category display has correct title' );
# XXX case here?
like( $html, qr{<li>\s*<a.*href="/lite/category/admin/Welcome".*>\s*Welcome\s*</a>},
    'category Welcome is listed with correct url and name' );

# get a specific category
my $html_from_lc_category = $lite->category('welcome');
$html = $lite->category('Welcome');

is ( lc($html_from_lc_category), lc($html), 'case of category does not change content' );
# XXX case is odd
like ( $html, qr{\Q<title>Admin Wiki : Category Welcome</title>},
    'category display for welcome has right title' );
like ( $html, qr{<li>\s+<a.*href="/lite/page/admin/start_here".*>\s*Start here\s*</a>}ms,
    'category display for welcome links to included page' );

# get category changes, different case
my $html_from_rc_category = $lite->recent_changes('welcome');
$html = $lite->recent_changes('Welcome');

is ( lc($html_from_rc_category), lc($html), 'case of rc category does not change content' );
# XXX case is odd
like ( $html, qr{\Q<title>Admin Wiki : Recent Changes in Welcome</title>},
    'rc category display for welcome has right title' );
like ( $html, qr{<li>\s+<a.*href="/lite/page/admin/start_here".*>\s*Start here\s*</a>}ms,
    'rc category display for welcome links to included page' );
