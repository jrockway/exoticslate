#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More;
use mocked 'Socialtext::User';
use mocked 'Socialtext::Log', qw(:tests);

BEGIN {
    if (!-e 't/lib/Socialtext/People/Profile.pm') {
        plan skip_all => 'People is not linked in';
        exit;
    }
    
    plan tests => 46;
}

use mocked 'Socialtext::People::Profile';
$Socialtext::MassAdd::Has_People_Installed = 1;
use_ok 'Socialtext::MassAdd';

# Explicitly set this user to undef, so we don't return a default mocked user
$Socialtext::User::Users{guybrush} = undef;

my $PIRATE_CSV = <<'EOT';
guybrush,guybrush@monkeyisland.com,Guybrush,Threepwood,password,Captain,Pirates R. Us,High Seas,123-456-YARR,,123-HIGH-SEA
EOT

Add_one_user_csv: {
    clear_log();
    my @successes;
    my @failures;
    Socialtext::MassAdd->users(
        csv => $PIRATE_CSV,
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    is_deeply \@successes, ['Added user guybrush'], 'success message ok';
    logged_like 'info', qr/Added user guybrush/, '... message also logged';
    is_deeply \@failures, [], 'no failure messages';
    is delete $Socialtext::User::Confirmation_info{guybrush}, undef,
        'confirmation is not set';
    is delete $Socialtext::User::Sent_email{guybrush}, undef,
        'confirmation email not sent';
}

Add_user_already_added: {
    local $Socialtext::User::Users{guybrush} = Socialtext::User->new(
        username => 'guybrush',
    );

    Profile_data_needs_update: {
        clear_log();
        my @successes;
        my @failures;
        Socialtext::MassAdd->users(
            csv => $PIRATE_CSV,
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        is_deeply \@successes, ['Updated user guybrush'], 'success message ok';
        logged_like 'info', qr/Updated user guybrush/, '... message also logged';
        is_deeply \@failures, [], 'no failure messages';
    }

    Profile_data_already_up_to_date: {
        local $Socialtext::People::Profile::Profiles{1}
            = Socialtext::People::Profile->new(
                position     => 'Captain',   company    => 'Pirates R. Us',
                location     => 'High Seas', work_phone => '123-456-YARR',
                mobile_phone => '',          home_phone => '123-HIGH-SEA',
            );
        my @successes;
        my @failures;
        Socialtext::MassAdd->users(
            csv => $PIRATE_CSV,
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        is_deeply \@successes, ['No changes for user guybrush'],
            'success message ok';
        is_deeply \@failures, [], 'no failure messages';
    }

    Password_needs_update: {
        local $Socialtext::User::Users{guybrush} = Socialtext::User->new(
            username => 'guybrush',
            password => 'elaine',
        );
        local $Socialtext::People::Profile::Profiles{1}
            = Socialtext::People::Profile->new(
                position     => 'Captain',   company    => 'Pirates R. Us',
                location     => 'High Seas', work_phone => '123-456-YARR',
                mobile_phone => '',          home_phone => '123-HIGH-SEA',
            );
        my @successes;
        my @failures;
        Socialtext::MassAdd->users(
            csv => $PIRATE_CSV,
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        is_deeply \@successes, ['Updated user guybrush'], 'success message ok';
        is_deeply \@failures, [], 'no failure messages';
        is $Socialtext::User::Users{guybrush}->password, 'password',
            'password was updated';
    }

    First_last_name_update: {
        local $Socialtext::User::Users{guybrush} = Socialtext::User->new(
            username => 'guybrush',
            password => 'password',
            first_name => 'Herman',
            last_name => 'Toothrot'
        );
        local $Socialtext::People::Profile::Profiles{1}
            = Socialtext::People::Profile->new(
                position     => 'Captain',   company    => 'Pirates R. Us',
                location     => 'High Seas', work_phone => '123-456-YARR',
                mobile_phone => '',          home_phone => '123-HIGH-SEA',
            );
        my @successes;
        my @failures;
        Socialtext::MassAdd->users(
            csv => $PIRATE_CSV,
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        is_deeply \@successes, ['Updated user guybrush'], 'success message ok';
        is_deeply \@failures, [], 'no failure messages';
        is $Socialtext::User::Users{guybrush}->first_name, 'Guybrush',
            'first_name was updated';
        is $Socialtext::User::Users{guybrush}->last_name, 'Threepwood',
            'last_name was updated';
    }

    Profile_update: {
        local $Socialtext::People::Profile::Profiles{1}
            = Socialtext::People::Profile->new(
                position     => 'Chef',          company    => 'Scumm Bar',
                location     => 'Monkey Island', work_phone => '123-456-YUCK',
                mobile_phone => '',              home_phone => '123-HIGH-SEA',
            );
        my @successes;
        my @failures;
        Socialtext::MassAdd->users(
            csv => $PIRATE_CSV,
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        is_deeply \@successes, ['Updated user guybrush'], 'success message ok';
        is_deeply \@failures, [], 'no failure messages';

        my $profile = $Socialtext::People::Profile::Profiles{1};
        is $profile->position, 'Captain', 'People position was updated';
        is $profile->company, 'Pirates R. Us', 'People company was updated';
        is $profile->location, 'High Seas', 'People location was updated';
        is $profile->work_phone, '123-456-YARR', 'People work_phone was updated';
    }

    Update_with_no_people_installed: {
        local $Socialtext::MassAdd::Has_People_Installed = 0;
        my @successes;
        my @failures;
        Socialtext::MassAdd->users(
            csv => $PIRATE_CSV,
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        is_deeply \@successes, ['No changes for user guybrush'],
            'success message ok';
        is_deeply \@failures, [], 'no failure messages';
    }
}

Bad_email_address: {
    local $Socialtext::User::Users{lechuck} = undef;
    my $bad_csv = $PIRATE_CSV . <<'EOT';
lechuck,ghostlechuck.com,Ghost Pirate,LeChuck,password,Ghost,Ghost Pirates Inc,Netherworld,,,
EOT
    clear_log();
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
    logged_like 'error', qr/email is a required field, but could not be parsed/, '... message also logged';
}

No_password: {
    # strip out the password from the csv line
    (my $csv = $PIRATE_CSV) =~ s/password//;
    my @successes;
    my @failures;
    Socialtext::MassAdd->users(
        csv => $csv,
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    is_deeply \@successes, ['Added user guybrush'], 'success message ok';
    is_deeply \@failures, [], 'no failure messages';
    is delete $Socialtext::User::Confirmation_info{guybrush}, 0,
        'confirmation is set';
    is delete $Socialtext::User::Sent_email{guybrush}, 1,
        'confirmation email sent';
}

Bad_password: {
    # Change the password to something too small
    (my $csv = $PIRATE_CSV) =~ s/password/pw/;
    clear_log();
    my @successes;
    my @failures;
    Socialtext::MassAdd->users(
        csv => $csv,
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    is_deeply \@successes, [], 'user was not added';
    is_deeply \@failures,
        ['Line 1: Passwords must be at least 6 characters long.'],
        'correct failure message';
    logged_like 'error', qr/Passwords must be at least 6 characters long/, '... message also logged';
}

Create_user_with_no_people_installed: {
    local $Socialtext::MassAdd::Has_People_Installed = 0;
    my @successes;
    my @failures;
    Socialtext::MassAdd->users(
        csv => $PIRATE_CSV,
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    is_deeply \@successes, ['Added user guybrush'], 'success message ok';
    is_deeply \@failures, [], 'no failure messages';
    is delete $Socialtext::User::Confirmation_info{guybrush}, undef,
        'confirmation is not set';
    is delete $Socialtext::User::Sent_email{guybrush}, undef,
        'confirmation email not sent';
}

Missing_username: {
    my $bad_csv = $PIRATE_CSV . <<'EOT';
,ghost@lechuck.com,Ghost Pirate,LeChuck,password,Ghost,Ghost Pirates Inc,Netherworld,,,
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
        ['Line 2: username is a required field, but it is not present.'],
        'correct failure message';
}

Missing_email: {
    my $bad_csv = $PIRATE_CSV . <<'EOT';
lechuck,,Ghost Pirate,LeChuck,password,Ghost,Ghost Pirates Inc,Netherworld,,,
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
        ['Line 2: email is a required field, but it is not present.'],
        'correct failure message';
}

Bogus_csv: {
    my $bad_csv = <<"EOT";
This line isn't CSV but we're going to try to parse/process it anyways
lechuck\tghost\@lechuck.com\tGhost Pirate\tLeChuck\tpassword\tGhost\tGhost Pirates Inc\tNetherworld\t\t\t
$PIRATE_CSV
EOT
    my @successes;
    my @failures;
    Socialtext::MassAdd->users(
        csv => $bad_csv,
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );

    is_deeply \@failures,
        ['Line 1: could not be parsed.  Skipping this user.',
         'Line 2: could not be parsed.  Skipping this user.',
        ],
        'correct failure message';
    is_deeply \@successes, ['Added user guybrush'], 'continued on to add next user';
}
