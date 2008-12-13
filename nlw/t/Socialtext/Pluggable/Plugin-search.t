#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext tests => 3;
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

# 'central_page_templates' maybe got removed?
my @expected = qw(
advanced_getting_around
can_i_change_something
central_page_important_links
congratulations_you_know_how_to_use_a_workspace
conversations
document_library_template
document_templates
documents_that_people_are_working_on
expense_report_template
how_do_i_find_my_way_around
how_do_i_make_a_new_page
how_do_i_make_links
learning_resources
lists_of_pages
meeting_agendas
meeting_minutes_template
member_directory
people
project_plans
project_summary_template
quick_start
start_here
what_else_is_here
what_if_i_make_a_mistake
what_s_the_funny_punctuation
workspace_tour_table_of_contents
);

my @page_ids = sort map { $_->{page_id} } @{$pages->{rows}};
is_deeply \@page_ids, \@expected, "Tag search returned the right page results";
exit;


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
