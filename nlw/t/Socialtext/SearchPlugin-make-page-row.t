#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 5;
fixtures( 'admin' );
use Socialtext::SearchPlugin;
use Socialtext::Page;

my $hub = new_hub('admin');

my $Singapore = join '', map { chr($_) } 26032, 21152, 22369;

my $utf8_page = Socialtext::Page->new(hub=>$hub)->create(
    title => $Singapore,
    content => 'hello',
    creator => $hub->current_user,
);

my $page_uri = $utf8_page->uri;

ok( keys(%{make_page_row($page_uri)}),
    'passing an encoded utf8 page uri returns hash with keys' );
ok( !keys(%{make_page_row($Singapore)}),
    'passing utf8 string returns empty hash' );
ok( !keys(%{make_page_row('this page does not exist')}),
    'non existent page returns empty hash' );
ok( keys(%{make_page_row('start_here')}),
    'normal existing page returns hash with keys' );
# sigh, osx doesn't care about case in filenames as much as we might like...
ok( !keys(%{make_page_row('Start Here')}) || $^O =~ /darwin/,
    'existing page as name not uri returns empty or this is a mac' );

sub make_page_row {
    my $uri_candidate = shift;
    my $output = $hub->search->_make_page_row(
        FakePageHit->new(
            $uri_candidate,
            $hub->current_workspace->name
        )
    );
    return $output;
}

package FakePageHit;

sub new {
    my ( $class, $page_uri, $workspace_name ) = @_;
    return bless { page_uri => $page_uri, workspace_name => $workspace_name },
        $class;
}

sub page_uri {
    my $self = shift;
    return $self->{page_uri};
}

sub workspace_name {
    my $self = shift;
    return $self->{workspace_name};
}

1;
