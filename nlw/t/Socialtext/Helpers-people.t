#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::Socialtext;

BEGIN {
    if (!-e 't/lib/Socialtext/People/Profile.pm') {
        plan skip_all => 'People is not linked in';
        exit;
    }
    
    plan tests => 2;
}

fixtures('admin');
my $hub = new_hub('admin');

my $p1 = Socialtext::User->create(
    username => "user1-$$",
    email_address => "1-$$\@devnull.socialtext.net",
);
my $p2 = Socialtext::User->create(
    username => "user2-$$",
    email_address => "2-$$\@devnull.socialtext.net",
);
my $p3 = Socialtext::User->create(
    username => "user3-$$",
    email_address => "3-$$\@devnull.socialtext.net",
);

_get_people_watchlist_for_people: {
    my $user1 =  Socialtext::User->new( user_id => $p1->user_id );
    $hub->current_user($user1);
    my $profile1 = Socialtext::People::Profile->GetProfile($user1);
    
    $profile1->watchlist( { } );
    $profile1->save_related;

    my $watchlist = $hub->helpers->_get_people_watchlist_for_people();
    is_deeply $watchlist, [ 
        ],
        "_get_people_watchlist gets empty watched people list";
}

_get_people_watchlist_for_people: {
    my $user1 =  Socialtext::User->new( user_id => $p1->user_id );
    $hub->current_user($user1);
    my $profile1 = Socialtext::People::Profile->GetProfile($user1);
    my $profile2 = Socialtext::People::Profile->GetProfile($p2->user_id);
    my $profile3 = Socialtext::People::Profile->GetProfile($p3->user_id);
    
    $profile1->watchlist( 
        {
            $profile2->id => $profile2->best_full_name,
            $profile3->id => $profile3->best_full_name
        } 
    );
   
    $profile1->save_related;

    my $watchlist = $hub->helpers->_get_people_watchlist_for_people();
    my $uid_2 = $p2->user_id;
    my $bfn_2 = $profile2->best_full_name;
    my $uid_3 = $p3->user_id;
    my $bfn_3 = $profile3->best_full_name;
    is_deeply $watchlist, [ 
        { 
            pic_url => "/data/people/$uid_2/small_photo",
            label => $bfn_2,
            link => "/?profile/$uid_2"
        },
        { 
            pic_url => "/data/people/$uid_3/small_photo",
            label => $bfn_3,
            link => "/?profile/$uid_3"
        }
        ],
        "_get_people_watchlist gets watched people";
}


