#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 1;
fixtures( 'admin' );

use Socialtext::Pages;

my $hub = new_hub('admin');
my $user = $hub->current_user( Socialtext::User->new( username => 'devnull1@socialtext.com' ) );

{
    my $page = Socialtext::Page->new(hub => $hub)->create(
        title => 'a freshie page',
        content => 'with freshie content',
        creator => $hub->current_user,
    );
}

SKIP: {
    skip "chris needs to fix this", 1 if 1;

    my $page = $hub->pages->new_from_name('a freshie page');

    my $date = $page->metadata->Date;
    my $datetime_for_user = $page->datetime_for_user($hub->current_user);

    is ( as_epoch($date), as_epoch($datetime_for_user),
        'date and datetime for user should be same time' );
}

