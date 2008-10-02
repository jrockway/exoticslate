#!perl
# @COPYRIGHT@

# These tests were originally written as a reverse-engineering of the
# perceived behaviour of the RecentChangesPlugin module as of 2008-10-01.

use warnings;
use strict;

use mocked 'Socialtext::CGI';
use mocked 'Socialtext::ChangeEvent';
use Socialtext::User;
use Socialtext::Page;
use Socialtext::RecentChangesPlugin;
use Socialtext::Hub;
use DateTime;
use DateTime::Duration;
use Test::Socialtext tests => 66;
fixtures( 'foobar_no_pages' );

my $now = time;

=head1 DESCRIPTION

Test that orphans are correctly discovered and correctly not
displayed when they are deleted.

=cut

my $hub = new_hub('foobar', 'system-user');
my $pages = $hub->pages;

ok $hub->current_user, "some user is set";
is $hub->current_workspace->name, "foobar", "current ws is foobar";

my @p;
$p[1] = "page one";
my $page_one = Socialtext::Page->new( hub => $hub )->create(
    title   => $p[1],
    content => "bbb this is page one, crazy",
    creator => $hub->current_user,
);

$p[2] = "page two";
my $page_two = Socialtext::Page->new( hub => $hub )->create(
    title   => $p[2],
    content => "ccc this is page two, crazy",
    creator => Socialtext::User->Guest(),
);
my $two_days_ago = DateTime->now() - DateTime::Duration->new(days => 2);
$page_two->hard_set_date($two_days_ago, $hub->current_user);

$p[3] = "page three";
my $page_three = Socialtext::Page->new( hub => $hub )->create(
    title   => $p[3],
    content => "aaa this is page three, wow!",
    creator => $hub->current_user,
);
my $yesterday = DateTime->now() - DateTime::Duration->new(days => 1);
$page_three->hard_set_date($yesterday, $hub->current_user);

$p[4] = "page four";
my $page_four = Socialtext::Page->new( hub => $hub )->create(
    title   => $p[4],
    content => "zzz this is page four, nifty!",
    creator => $hub->current_user,
);
my $a_year_ago = DateTime->now() - DateTime::Duration->new(years => 1);
$page_four->hard_set_date($a_year_ago, $hub->current_user);

# title asc: 
my @title_asc = @p[1,3,2];
my @title_desc = reverse @title_asc;
my @date_asc = @p[2,3,1];
my @date_desc = reverse @date_asc;

my $last_result_set;

sub mocked_display_results {
    my $self = shift;
    my @args = @_;
    $last_result_set = $self->result_set();
    $self->result_set(undef);
}

{
    no warnings qw(redefine once);
    *Socialtext::RecentChangesPlugin::display_results =
        \&mocked_display_results;
}

sub changes_ok {
    my %p = @_;
    my $params = $p{cgi};
    my $expected = $p{result};
    my $name = $p{name} or die "name your test!";

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $last_result_set = undef;

    my $rc = $hub->recent_changes;
    my $cgi = Socialtext::RecentChanges::CGI->new(
        changes => '',
        direction => '',
        sortby => '',
        %$params,
    );
    $rc->{cgi} = $cgi;

    $rc->changes;

    ok $last_result_set, "$name : got a result set";
    ok $last_result_set->{rows}, "$name : got rows in the result set";
    my @titles = map {$_->{Subject}} @{$last_result_set->{rows}};
    is_deeply \@titles, $expected,
        "$name : items sorted";
}

base_case: {
    changes_ok(
        cgi => {},
        result => [@date_desc],
        name => 'all defaults (date desc)',
    );
}

sort_by_date: {
    changes_ok(
        cgi => {sortby => 'Date', direction => 'asc'},
        result => [@date_asc],
        name => 'by date, asc'
    );
    changes_ok(
        cgi => {sortby => 'Date', direction => 'desc'},
        result => [@date_desc],
        name => 'by date, desc'
    );
    changes_ok(
        cgi => {sortby => 'Date'},
        result => [@date_desc],
        name => 'by date, default (desc)'
    );
}

sort_by_title: {
    changes_ok(
        cgi => {sortby => 'Subject', direction => 'asc'},
        result => [@title_asc],
        name => 'by title, asc'
    );
    changes_ok(
        cgi => {sortby => 'Subject', direction => 'desc'},
        result => [@title_desc],
        name => 'by title, desc'
    );
    changes_ok(
        cgi => {sortby => 'Subject'},
        result => [@title_asc],
        name => 'by title, default (asc)'
    );
}

sort_by_summary: {
    changes_ok(
        cgi => {sortby => 'Summary', direction => 'asc'},
        result => [@p[3,1,2]],
        name => 'by summary, asc'
    );
    changes_ok(
        cgi => {sortby => 'Summary', direction => 'desc'},
        result => [@p[2,1,3]],
        name => 'by summary, desc'
    );
    changes_ok(
        cgi => {sortby => 'Summary'},
        result => [@p[3,1,2]],
        name => 'by summary, default (asc)'
    );
}

sort_by_username: {
    # assumption:
    ok(Socialtext::User->SystemUser->username gt 
       Socialtext::User->Guest->username, "system user is after guest");

    changes_ok(
        cgi => {sortby => 'username', direction => 'asc'},
        result => [@p[2,1,3]],
        name => 'by username, asc'
    );
    changes_ok(
        cgi => {sortby => 'username', direction => 'desc'},
        result => [@p[3,1,2]],
        name => 'by username, desc'
    );
    changes_ok(
        cgi => {sortby => 'username'},
        result => [@p[2,1,3]],
        name => 'by username, default (asc)'
    );
}

sort_by_rev_count: {
    is $page_one->revision_count, 1, "page one has 1 revs";
    is $page_two->revision_count, 2, "page two has 2 revs";
    is $page_three->revision_count, 2, "page three has 2 revs";

    # secondary sort is pinned to 'title asc'

    changes_ok(
        cgi => {sortby => 'revision_count', direction => 'asc'},
        result => [@p[1,3,2]],
        name => 'by revs, asc'
    );
    changes_ok(
        cgi => {sortby => 'revision_count', direction => 'desc'},
        result => [@p[3,2,1]],
        name => 'by revs, desc'
    );
    changes_ok(
        cgi => {sortby => 'revision_count'},
        result => [@p[3,2,1]],
        name => 'by revs, default (desc)'
    );
}

all_pages: {
    changes_ok(
        cgi => {action => 'changes', changes => 'all'},
        result => [@p[1,3,2,4]],
        name => 'all by default (date desc)'
    );

    changes_ok(
        cgi => {action => 'changes', changes => 'all', 
                sortby => 'Date', direction => 'asc'},
        result => [@p[4,2,3,1]],
        name => 'all by date asc',
    );

    changes_ok(
        cgi => {action => 'changes', changes => 'all', 
                sortby => 'Subject', direction => 'desc'},
        result => [@p[2,3,1,4]],
        name => 'all by title desc'
    );

    changes_ok(
        cgi => {action => 'changes', changes => 'all', 
                sortby => 'Subject', direction => 'asc'},
        result => [@p[4,1,3,2]],
        name => 'all by title desc'
    );
}
