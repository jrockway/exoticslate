#!perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Live fixtures => ['admin_with_extra_pages', 'help'];
use Test::More;
use Test::Socialtext::Environment;
use SOAP::Lite;
#use SOAP::Lite +trace => 'all';
use Data::Dumper;
use CGI::Cookie;
use Socialtext::System qw/shell_run/;
use Socialtext::Jobs;
use Socialtext::Page;
use Socialtext::User;

# this test insn't stable with regards to changes in fixtures or
# extra pages
plan tests => 53;

# light em up, we want some web servage
# but that's it
my $live           = Test::Live->new();
my $base_uri       = $live->base_url;
my $wsdl           = $base_uri . '/static/wsdl/0.9.wsdl';
my $user           = 'devnull1@socialtext.com';
my $good_user      = 'devnull11@socialtext.com';
my $bad_user       = 'lovemonkey@example.com';
my $homeless_user  = 'devnull2@socialtext.com';                # no workspaces
my $password       = 'd3vnu11l';
my $workspace_name = 'admin';
my $new_workspace_name = 'xyzzy';    # this should not exist

my $hub = Test::Socialtext::Environment->instance()
    ->hub_for_workspace($workspace_name);

my $soap = SOAP::Lite->service($wsdl)
    ->on_fault( sub { my ($soap, $res) = @_;
                die ref $res ? $res->faultstring : $soap->transport->status, "\n";
            } );
our $actor_token;
my $act_as_token;

# check the heartBeat
{
    my $response = $soap->heartBeat();
    # Tue May 30 13:34:36 2006
    like( $response, qr/\A\w{3}\s+\w{3}\s+\d+\s+\d+:\d+:\d+\s+\d{4}\z/,
        "heartBeat time, $response looks like a time string" );
    my $http_response = $soap->transport->http_response();
    is $http_response->header('Content-type'), 'text/xml; charset=utf-8', 'content type of response is text/xml';
}

# good auth
{
    my $response = $soap->getAuth($user, $password, $workspace_name);
    like $response, qr/user_id&\d+/, 'response contains a user id';
    like $response, qr/MAC&[^&]+&workspace_id&[^&]+$/,
        'response contains a MAC and workspace_id';
    $actor_token = $response;
}

# auth on a nonexistent workspace
{
    eval { $soap->getAuth( $user, $password, $new_workspace_name ) };
    like
        $@,
        qr/Invalid workspace name/,
        "Bogus workspace name raises fault.";
}

# missing parameters
{
    required_ok( 'getAuth' );
    required_ok( 'getAuth', $user );
    required_ok( 'getAuth', $user, $password );
    required_ok( 'setPage' );
    required_ok( 'setPage', $actor_token );
    required_ok( 'getChanges' );
    required_ok( 'getSearch' );
    required_ok( 'getSearch', $actor_token );
    required_ok( 'getPage' );
    required_ok( 'getPage', $actor_token );
}

# good act_as auth
{
    my $response
        = $soap->getAuth( $user, $password, $workspace_name, $good_user );
    like $response, qr/user_id&\d+/, 'response contains a user id';
    like $response, qr/MAC&/, 'response contains a MAC';
    like $response, qr/act_as&$good_user/, 'response contains the right act_as';
    $act_as_token = $response;
}

{
    eval {
        my $response
            = $soap->getAuth( $user, $password, 'help-en', $good_user );
    };
    like $@, qr/Impersonate denied/, 'bad credentials cause a fault';
}

# bad auth
{
    eval {
        my $response
            = $soap->getAuth( $bad_user, $password, $workspace_name );
    };
    like $@, qr/Invalid user:/, 'bad credentials cause a fault';
}

# user exists, but ain't in that workspace
{
    Socialtext::User->create(
        username      => $homeless_user,
        email_address => $homeless_user,
        password      => $password,
    );
    eval {
        $soap->getAuth( $homeless_user, $password, $workspace_name );
    };
    like $@, qr/Access denied/, "We don't let just _anybody_ in!";
}

# tweak the MAC, should get auth failure fault.
{
    local $actor_token = $actor_token;
    $actor_token =~ s/MAC&/MAC&xyzzy/;

    eval { _get_page_content('wikitext') };
    like $@, qr/Invalid MAC Secret/, 'Bad MAC Secret raises client fault.';
}

# tweak the user_id, should get auth failure fault.
{
    local $actor_token = $actor_token;
    $actor_token =~ s/user_id&(\d+)/"user_id&" . ($1 - 1)/e;

    eval { _get_page_content('wikitext') };
    like
        $@,
        qr/Invalid MAC Secret/,
        'Altered auth token user_id raises client fault.';
}

# workspace
{
    eval {
        my $response
            = $soap->getAuth( $user, $password, 'monkey' );
    };
    like $@, qr/Invalid workspace/, 'invalid workspace name';
}

# get a page as wikitext
{
    my $content = _get_page_content('wikitext');
    like( $content, qr/\A\^\^ Welcome to the Workspace\n/,
        'first line of wikitext content is expected welcome message' );
    like( $content, qr{_Put your name below and turn it into a link_ \(http:base/images/wikiwyg_icons/link.gif\)\Z},
        'last line of wikitext content is expected sign up message' );
}

# do it again, this time with default full html
{
    my $content = _get_page_content('html');
    like( $content,
        qr{<div class="wiki">\n<h2 id="welcome_to_the_workspace">Welcome to the Workspace</h2>},
        'first line of html output is welcome message' );
    like( $content, qr{"\Q$base_uri/help-en/index.cgi?socialtext_documentation"},
        'href to documentation is fully qualified for the right workspace' );
}

# and again, this time lite
{
    my $content = _get_page_content('html/Lite');
    like( $content,
        qr{<div class="wiki">\n<h2 id="welcome_to_the_workspace">Welcome to the Workspace</h2>},
        'first line of html output is welcome message' );
    like( $content, qr{"\Q/lite/page/help-en/socialtext_documentation"},
        'href to documentation is formatted for lite' );
}

# request a bogus type
{
    eval { _get_page_content('pdf') };
    like( $@, qr/Unknown format/ );
}

# and recent changes
{
    # make the count higher than there are pages
    my $response = _get_changes('recent changes', 1000);
    # expect only 32 pages because that's what's in the workspace total
    is( scalar @$response, 32, 'there are 32 changes' );
    ok( grep( 'Admin Wiki', map { $_->{subject} } @$response ),
        'changes contain admin wiki page' );
}

# recent changes with other case and no count
{
    my $response = _get_changes('Recent Changes', 1000);
    # expect only 32 pages because that's what's in the workspace total
    is( scalar @$response, 32,
        'there are 32 changes with bad case category' );
    ok( grep( 'Admin Wiki', map { $_->{subject} } @$response ),
        'changes contain admin wiki page when bad case category' );
}

# recent changes without category or count
{
    my $response = _get_changes();
    # expect only ten pages because there are more than 10 in the workspace
    is( scalar @$response, 10, 'there are ten changes defaulting args' );
    ok( grep( 'Admin Wiki', map { $_->{subject} } @$response ),
        'changes contain admin wiki page defaulting args' );
}

# recent changes with category welcome
{
    my $response = _get_changes('welcome', 1000);
    # expect only eighteen pages because that's what's in the welcome category
    is(
        scalar @$response,
        18,
        'there are eighteen changes in category welcome'
    );
    ok(
        grep( 'Welcome', map { $_->{subject} } @$response ),
        'help changes contain welcome page'
    );
}

# setPage in a simple way
SETPAGE: {
   my $pageRef = eval { $soap->setPage(
            $actor_token,
            'a brand new page',
            "^Hello People\n\nI am in the house\n",
        );
    };
    ok( !$@, "eval should not set \$\@: $@" );
    like $pageRef->{pageContent}, qr/I am in the house\n\z/ms,
        'page content gets set';
}

SETPAGE_ACT_AS: {
    my $pageRef = eval {
        $soap->setPage(
            $act_as_token,
            'a brand new page',
            'monkey see',
        );
    };
    ok ( !$@, "eval should not set \$\@: $@" );
    is $pageRef->{pageContent}, "monkey see\n", 'page content is set';
    is $pageRef->{author}, $good_user,
        'page author is set to act_as user';
}

# setPage with a bogus page id
{
    my $bad_page_id = 'X' x (Socialtext::Page::_MAX_PAGE_ID_LENGTH + 1);
    eval {
        $soap->setPage(
            $actor_token,
            $bad_page_id,
            "Whenever there's trouble, we're there on the double"
        );
    };
    like( $@, qr/Invalid page id/, "Page ID length is checked.\n" );
}

# XXX need a test for bad token and a good token that is not an
# admin user

# clean the ceq queue prior to this save so it's the only thing
# in the queue
Socialtext::Jobs->clear_jobs();

# do the same page again
RESETPAGE: {
    my $pageRef = eval { $soap->setPage(
            $actor_token,
            'a brand new page',
            "ontology",
        );
    };
    ok( !$@, "eval should not set \$\@: $@" );
    is $pageRef->{pageContent}, "ontology\n", 'page content gets reset';
}

# run the ceqlotron
shell_run("$ENV{ST_CURRENT}/nlw/bin/ceqlotron -o -f");

SEARCH: {
    my $response = _getSearch('ontology');
    is( scalar @$response, 1, 'there is one response for ontology' );
    ok( grep( 'a brand new page', map { $_->{subject} } @$response ),
        'search results contain a brand new page' );
}

UTF8: {
    my $page     = Socialtext::Page->new( hub => $hub, id => 'babel' );
    my $wikitext = $page->content;
    my $html     = $page->to_html_or_default;

    my $pageRef
        = eval { $soap->getPage( $actor_token, 'babel', 'wikitext' ); };
    ok( !$@, "eval of getPage should not set \$\@: $@" );
    is $pageRef->{pageContent}, $wikitext,
        'babel wikitext content same on both sides';

    $pageRef = eval { $soap->getPage( $actor_token, 'babel', 'html' ); };
    ok( !$@, "eval of getPage should not set \$\@: $@" );
    is $pageRef->{pageContent}, $html,
        'babel html content same on both sides';
}

# TODO
# check bad method fault
# check bad args fault
# check namespacing issues (.NET and jwsdp issues with default SOAP::Lite)

sub _get_changes {
    my $category = shift;
    my $count    = shift;
    return $soap->getChanges(
        $actor_token,
        $category,
        $count,
    );
}

sub _getSearch {
    my $query = shift;
    return $soap->getSearch(
        $actor_token,
        $query,
    );
}

sub _get_page_content {
    my $format = shift;
    return $soap->getPage(
        $actor_token,
        'admin wiki',                 # page name
        $format,                      # format
    )->{pageContent};
}

sub required_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my ( $method, @args ) = @_;

    eval { $soap->$method(@args) };
    like(
        $@,
        qr/Required parameter/,
        "$method complains with only " . scalar @args . " args"
    );
}
