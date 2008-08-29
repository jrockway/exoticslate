#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext tests => 1;
use Socialtext::User;
use Socialtext::URI;
use Socialtext::Account;
use Socialtext::Workspace;
use Socialtext::AppConfig;
use Data::Dumper;
fixtures( 'admin', 'exchange' );

use Socialtext::Ceqlotron;
use Socialtext::Search::AbstractFactory;

Socialtext::Ceqlotron::clean_queue_directory();

my $hub = new_hub('admin');
Socialtext::Search::AbstractFactory->GetFactory->create_indexer('admin')
    ->index_workspace('admin');
ceqlotron_run_synchronously();

use_ok 'Socialtext::Pluggable::Plugin';
use_ok 'Socialtext::Pluggable::Adapter';

my $system_user = Socialtext::User->SystemUser;
my $adapter = Socialtext::Pluggable::Adapter->new;
my $plug = Socialtext::Pluggable::Plugin->new;
$plug->{hub} = $hub;

#search
my $pages = $plug->search('tag:welcome');
is scalar(@{$pages->{rows}}), 18, 'Tag search returned the right number of pages';

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
