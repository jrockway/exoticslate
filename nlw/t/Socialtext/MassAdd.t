#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More;
use mocked 'Socialtext::User';

BEGIN {
    if (!-e 't/lib/Socialtext/People/Profile.pm') {
        plan skip_all => 'People is not linked in';
        exit;
    }
    
    plan tests => 16;
}

use mocked 'Socialtext::People::Profile';
$Socialtext::MassAdd::Has_People_Installed = 1;
use_ok 'Socialtext::MassAdd';

# Explicitly set this user to undef, so we don't return a default mocked user
$Socialtext::User::Users{guybrush} = undef;

my $PIRATE_CSV = <<'EOT';
guybrush,guybrush@monkeyisland.com,Guybrush,Threepwood,password,Captain,Pirates R. Us,High Seas,123-456-7890,,123-456-9876
EOT
Add_one_user_csv: {
    my @successes;
    my @failures;
    Socialtext::MassAdd->users(
        csv => $PIRATE_CSV,
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    is_deeply \@successes, ['Added user guybrush'], 'success message ok';
    is_deeply \@failures, [], 'no failure messages';
}

Add_user_already_added: {
    local $Socialtext::User::Users{guybrush} = Socialtext::User->new(
        username => 'guybrush',
    );
    Profile_data_needs_update: {
        my @successes;
        my @failures;
        Socialtext::MassAdd->users(
            csv => $PIRATE_CSV,
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        is_deeply \@successes, ['Added user guybrush'], 'success message ok';
        is_deeply \@failures, [], 'no failure messages';
    }
    Profile_data_already_up_to_date: {
        local $Socialtext::People::Profile::Profiles{1}
            = Socialtext::People::Profile->new(
                position     => 'Captain',   company    => 'Pirates R. Us',
                location     => 'High Seas', work_phone => '123-456-7890',
                mobile_phone => '',          home_phone => '123-456-9876',
            );
        my @successes;
        my @failures;
        Socialtext::MassAdd->users(
            csv => $PIRATE_CSV,
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        is_deeply \@successes, [], 'success message ok';
        is_deeply \@failures, [], 'no failure messages';
    }
    No_people_installed: {
        local $Socialtext::MassAdd::Has_People_Installed = 0;
        my @successes;
        my @failures;
        Socialtext::MassAdd->users(
            csv => $PIRATE_CSV,
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        is_deeply \@successes, [], 'success message ok';
        is_deeply \@failures, [], 'no failure messages';
    }
}

Bad_email_address: {
    local $Socialtext::User::Users{lechuck} = undef;
    my $bad_csv = $PIRATE_CSV . <<'EOT';
lechuck,ghostlechuck.com,Ghost Pirate,LeChuck,password,Ghost,Ghost Pirates Inc,Netherworld,,,
EOT
    my @successes;
    my @failures;
    Socialtext::MassAdd->users(
        csv => $bad_csv,
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    is_deeply \@successes, ['Added user guybrush'], 'success message ok';
    is_deeply \@failures,
        ['Line 2: email is a required field, but could not be parsed.'],
        'correct failure message';
}

# Fill in these tests
ok 1, 'no password';
ok 1, 'bad password';
ok 1, 'bad phone numbers';
ok 1, 'No People installed';
ok 1, 'tsv';
