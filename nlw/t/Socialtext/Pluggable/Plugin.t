#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;

BEGIN { push @INC, 't/plugin/mocked/lib' };

use Test::Socialtext tests => 26;
use Socialtext::User;
use Socialtext::URI;
use Socialtext::Account;
use Socialtext::Workspace;
use Socialtext::AppConfig;
fixtures( 'admin' );

use_ok 'Socialtext::Pluggable::Plugin';
use_ok 'Socialtext::Pluggable::Adapter';

my $code_base = Socialtext::AppConfig->code_base;
my $hub = new_hub('admin');
my $system_user = Socialtext::User->SystemUser;
my $adapter = Socialtext::Pluggable::Adapter->new;
my $plug = Socialtext::Pluggable::Plugin->new;
my $ws = Socialtext::Workspace->new(name => 'magic') ||
    Socialtext::Workspace->create(
        name       => 'magic',
        title      => 'Magical Title',
        account_id => Socialtext::Account->Socialtext()->account_id,
    );
$plug->hub($adapter->make_hub($system_user, $ws));
$plug->hub->rest(Rest->new);

# Config
is $plug->uri, Socialtext::URI::uri(path => 'magic/index.cgi'), 'uri';
is $plug->code_base, $code_base, 'code_base';

# CGI
%Query::p = (a => 1, b => 2);
is $plug->query_string, 'a=1;b=2', 'query_string';
is $plug->query->param('a'), 1, 'query 1';
is $plug->query->param('b'), 2, 'query 2';
is $plug->getContent, 'content', 'getContent';
is_deeply $plug->getContentPrefs, { content => 'prefs' }, 'getContentPrefs';

# User stuff
is_deeply $plug->user, $system_user, 'user';
is $plug->username, $system_user->username, 'username';
is $plug->best_full_name($system_user->username),
   $system_user->best_full_name(workspace => $ws),
   'best_full_name';

# Headers
$plug->header_out('Content_Type' => 'text/html');
my %header_out = $plug->header_out;
is $header_out{Content_Type}, 'text/html', 'header_out';
%Request::in = ( Accept => 'text/html' );
is $plug->header_in('Accept'), 'text/html', 'header_in';
my %in = $plug->header_in;
is_deeply \%in, {Accept=>'text/html'}, 'header_in';

# Cache stuff
$plug->cache_value(key => 'a', value => 1);
is $plug->value_from_cache('a'), 1, 'can retrieve cache value';

# Workspace
is $plug->current_workspace, $ws->name, 'current_workspace';

# Plugin functions
my %plugins = map { $_ => 1 } $plug->plugins;
ok $plugins{mocked}, 'Mocked plugin exists';
is $plug->plugin_dir('mocked'), "$code_base/plugin/mocked",
   'Mocked directory is correct';

# Page stuff
$plug->{hub} = $hub;
my $page = $plug->get_page(workspace_name => 'admin', page_name => 'Start Here');
ok defined $page, 'Page object found';
is $page->title, 'Start here', 'Fetched page from workspace';
$page = $plug->get_page(workspace_name => '12df', page_name => 'Start Here');
ok ! defined $page, 'No page object on invalid workspace';

# Tags
my @tags = $plug->tags_for_page(workspace_name => 'admin', page_name => 'Start Here');
is scalar(@tags), 1, 'Tag count is right';
is $tags[0], 'Welcome', 'first tag is right';
@tags = $plug->tags_for_page(workspace_name => '12hjs', page_name => 'Start Here');
is scalar(@tags), 0, 'Non-existant page has an empty tag list';

# Page Caching
# This one is kind of funky. When we fetch a page we cache it. So we add
# tags to the page we fetched but do not save the page. Then we ask for
# the tags for the page. If the page caching works, the call to get tags
# should use the cached page which will have our new tags 
$page = $plug->get_page(workspace_name => 'admin', page_name => 'Start Here');
@tags = $plug->tags_for_page(workspace_name => 'admin', page_name => 'Start Here');
my $before_count = scalar(@tags);
$page->add_tags('t1', 't2');
@tags = $plug->tags_for_page(workspace_name => 'admin', page_name => 'Start Here');
ok scalar(@tags) > $before_count, 'Plugin used cached page';

package Rest;
use strict;
use warnings;
our %query;
sub new { bless {}, $_[0] }
sub getContent { 'content' }
sub getContentPrefs { +{content => 'prefs'} }
sub query { Query->new }
sub request { Request->new }
sub header {
    my ($self, %headers) = @_;
    $self->{out} ||= {};
    $self->{out}{$_} = $headers{$_} for keys %headers;
    return %{$self->{out}};
}

package Request;
use strict;
use warnings;
our %in;
sub new { bless {}, $_[0] }
sub header_in { $in{$_[1]} }
sub headers_in { %in }

package Query;
use strict;
use warnings;
our %p;
sub new { bless {}, $_[0] }
sub param { $p{$_[1]} }
sub query_string { join ';', map { "$_=$p{$_}" } keys %p }
