#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::More qw(no_plan);
use Socialtext::User;
use Socialtext::Account;
use Socialtext::Workspace;
use Socialtext::AppConfig;

use_ok 'Socialtext::Pluggable::Plugin';
use_ok 'Socialtext::Pluggable::Adapter';

my $system_user = Socialtext::User->SystemUser;
my $adapter = Socialtext::Pluggable::Adapter->new;
my $plug = Socialtext::Pluggable::Plugin->new;
my $ws = Socialtext::Workspace->new( name => 'admin' );
$plug->hub($adapter->make_hub($system_user, $ws));
$plug->hub->rest(Rest->new);

# Config
is $plug->uri, 'http://topaz.socialtext.net:22018/admin/index.cgi', 'uri';
is $plug->code_base, Socialtext::AppConfig->code_base, 'code_base';

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

# Workspace
is $plug->current_workspace, $ws->name, 'current_workspace';

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
