#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 8;
fixtures( 'admin' );

use Socialtext::User;
use Socialtext::Workspace;

BEGIN {
    use_ok( 'Socialtext::Watchlist' );
}

my $hub = new_hub('admin');
my $user = Socialtext::User->new( username => 'devnull1@socialtext.com' );
my $ws = Socialtext::Workspace->new( name => 'admin' );

my $watchlist = Socialtext::Watchlist->new(
                    user      => $user,
                    workspace => $ws,
                );

my $page = $hub->pages->new_from_name('Admin Wiki');
my $other_page = $hub->pages->new_from_name('Help');

# Watchlist: empty
ok( ! $watchlist->has_page( page => $page ),
    'Admin Wiki is not in the watchlist' );

ok( $watchlist->has_page( page => $page ) eq '0',
    'false returned from has_page check' );

my @list = $watchlist->pages;
ok (!grep (/admin_wiki/, @list),
    'The list of watchlist pages does not have admin wiki');

$watchlist->add_page( page => $page );

# Watchlist: admin_wiki
ok( $watchlist->has_page( page => $page ),
    'Admin Wiki is now in the watchlist' );

$watchlist->add_page (page=>$other_page);

# Watchlist: admin_wiki, help
@list = $watchlist->pages;
ok (grep (/admin_wiki/, @list), 'Admin wiki is still in the watchlist');

$watchlist->remove_page (page=>$page);

# Watchlist: help
ok ( !$watchlist->has_page( page=> $page),
    ' Admin Wiki was removed from watchlist');

@list = $watchlist->pages;
ok (grep (/help/, @list), 'Help is still in the watchlist');
