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

_get_people_watchlist_for_people: {
    my $user1 =  Socialtext::User->new( user_id => 1 );
    $hub->current_user($user1);
    my $profile1 = Socialtext::People::Profile->GetProfile($user1);
    
    $profile1->watchlist( 
        {
        } 
    );
   
    $profile1->save_related;

    my $watchlist = $hub->helpers->_get_people_watchlist_for_people();
    is_deeply $watchlist, [ 
        ],
        "_get_people_watchlist gets empty watched people list";
}

_get_people_watchlist_for_people: {
    my $user1 =  Socialtext::User->new( user_id => 1 );
    $hub->current_user($user1);
    my $profile1 = Socialtext::People::Profile->GetProfile($user1);
    my $profile2 = Socialtext::People::Profile->GetProfile(2);
    my $profile3 = Socialtext::People::Profile->GetProfile(3);
    
    $profile1->watchlist( 
        {
            $profile2->id => $profile2->best_full_name,
            $profile3->id => $profile3->best_full_name
        } 
    );
   
    $profile1->save_related;

    my $watchlist = $hub->helpers->_get_people_watchlist_for_people();
    is_deeply $watchlist, [ 
        { 
            pic_url => "/data/people/3/small_photo",
            label => "devnull1",
            link => "/?profile/3"
        },
        { 
            pic_url => "/data/people/2/small_photo",
            label => "Guest User",
            link => "/?profile/2"
        }
        ],
        "_get_people_watchlist gets watched people";
}


