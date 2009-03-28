#!perl
# @COPYRIGHT@

use warnings;
use strict;
use Test::Socialtext tests => 9;

BEGIN {
    use_ok( 'Socialtext::Pages' );
}

###############################################################################
# Fixtures: admin
# - don't need *this* Workspace, but we *do* need the "devnull1" User to have
#   been created (as that's the default User used by 'new_hub()'
fixtures(qw( admin ));

my $wksp = Socialtext::Workspace->create(
    name => "wksp$$",
    title => "wksp$$",
    account_id => Socialtext::Account->Default->account_id,
);
my $hub = new_hub($wksp->name);
isa_ok( $hub, 'Socialtext::Hub' );
$wksp->add_user(user => $hub->current_user);

CREATE_NEW_PAGE: {
    my $page = $hub->pages->create_new_page();

    ok($page->isa('Socialtext::Page'), 'object is a Socialtext Page');
    like($page->title, qr/^devnull1/, 'title starts with the right name');
}

All_ids: {
    my @all_ids = $hub->pages->all_ids;
    ok @all_ids, 'found some ids';
}

All_since: {
    my @pages = $hub->pages->all_since(300);
    ok @pages, 'found some pages';
    @pages = $hub->pages->all_since(300, 1);
    ok @pages, 'found some active pages';
}

Random_page: {
    my $page = $hub->pages->random_page;
    ok $page->name, 'found a random page';
    ok $page->active, 'page is active';
}

