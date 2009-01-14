#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More;

BEGIN {
    if (!-e 't/lib/Socialtext/People/Profile.pm') {
        plan skip_all => 'People is not linked in';
        exit;
    }
    
    plan tests => 97;
}

use mocked 'Socialtext::People::Profile', qw(save_ok);
use mocked 'Socialtext::Log', qw(:tests);
use mocked 'Socialtext::User';
$Socialtext::MassAdd::Has_People_Installed = 1;

use_ok 'Socialtext::MassAdd';

my %userinfo = (
    username      => 'ronnie',
    email_address => 'ronnie@mrshow.example.com',
    first_name    => 'Ronnie',
    last_name     => 'Dobbs',
    password      => 'brut4liz3',
    position      => 'Criminal',
    company       => 'FUZZ',
    location      => '',
    work_phone    => '',
    mobile_phone  => '',
    home_phone    => ''
);

Add_from_hash: {
    clear_log();
    $Socialtext::User::Users{ronnie} = undef;

    happy_path: {
        my @successes;
        my @failures;
        my $mass_add = Socialtext::MassAdd->new(
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        $mass_add->add_user(%userinfo);
        is_deeply \@successes, ['Added user ronnie'], 'success message ok';
        logged_like 'info', qr/Added user ronnie/, '... message also logged';
        is_deeply \@failures, [], 'no failure messages';
        is delete $Socialtext::User::Confirmation_info{ronnie}, undef,
            'confirmation is not set';
        is delete $Socialtext::User::Sent_email{ronnie}, undef,
            'confirmation email not sent';
    }

    bad_profile_field: {
        no warnings 'redefine';
        local %Socialtext::People::Fields::InvalidFields = ( badfield => 1);
        local $userinfo{badfield} = 'badvalue';

        my @successes;
        my @failures;
        my $mass_add = Socialtext::MassAdd->new(
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        $mass_add->add_user(%userinfo);
        is scalar(@failures), 1, "just one failure";
        like $failures[0], qr/Profile field "badfield" could not be updated/;
        logged_like 'error',
            qr/Profile field "badfield" could not be updated/,
            '... message also logged';

        is_deeply \@successes, ['Added user ronnie'], 'success message ok';
        logged_like 'info', qr/Added user ronnie/, '... message also logged';
    }
}

my $PIRATE_CSV = <<'EOT';
username,email_address,first_name,last_name,password,position,company,location,work_phone,mobile_phone,home_phone
guybrush,guybrush@example.com,Guybrush,Threepwood,my_password,Captain,Pirates R. Us,High Seas,123-456-YARR,,123-HIGH-SEA
EOT

Add_one_user_csv: {
    # Explicitly set this user to undef, so we don't return a default mocked user
    $Socialtext::User::Users{guybrush} = undef;
    clear_log();
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($PIRATE_CSV);
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

    uneditable_profile_field: {
        local @Socialtext::People::Fields::UneditableNames = qw/mobile_phone/;
        local $userinfo{mobile_phone} = '1-877-AVAST-YE';

        my @successes;
        my @failures;
        my $mass_add = Socialtext::MassAdd->new(
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        $mass_add->add_user(%userinfo);
        is scalar(@failures), 1, "just one failure";
        like $failures[0], qr/Profile field "mobile_phone" could not be updated/;
        logged_like 'error',
            qr/Profile field "mobile_phone" could not be updated/,
            '... message also logged';

        is_deeply \@successes, ['Added user ronnie'], 'success message ok';
        logged_like 'info', qr/Added user ronnie/, '... message also logged';
    }

    Profile_data_needs_update: {
        clear_log();
        my @successes;
        my @failures;
        my $mass_add = Socialtext::MassAdd->new(
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        $mass_add->from_csv($PIRATE_CSV);
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
        my $mass_add = Socialtext::MassAdd->new(
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        $mass_add->from_csv($PIRATE_CSV);
        is_deeply \@successes, ['No changes for user guybrush'],
            'success message ok';
        is_deeply \@failures, [], 'no failure messages';
    }

    Password_needs_update: {
        local $Socialtext::User::Users{guybrush} = Socialtext::User->new(
            username => 'guybrush',
            password => 'elaine',
        );
        my @successes;
        my @failures;
        my $mass_add = Socialtext::MassAdd->new(
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        $mass_add->from_csv($PIRATE_CSV);
        is_deeply \@successes, ['Updated user guybrush'], 'success message ok';
        is_deeply \@failures, [], 'no failure messages';
        is $Socialtext::User::Users{guybrush}->password, 'my_password',
            'password was updated';
    }

    First_last_name_update: {
        local $Socialtext::User::Users{guybrush} = Socialtext::User->new(
            username => 'guybrush',
            password => 'my_password',
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
        my $mass_add = Socialtext::MassAdd->new(
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        $mass_add->from_csv($PIRATE_CSV);
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
        my $mass_add = Socialtext::MassAdd->new(
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        $mass_add->from_csv($PIRATE_CSV);
        is_deeply \@successes, ['Updated user guybrush'], 'success message ok';
        is_deeply \@failures, [], 'no failure messages';

        my $profile = $Socialtext::People::Profile::Profiles{1};
        is $profile->get_attr('position'), 'Captain', 'People position was updated';
        is $profile->get_attr('company'), 'Pirates R. Us', 'People company was updated';
        is $profile->get_attr('location'), 'High Seas', 'People location was updated';
        is $profile->get_attr('work_phone'), '123-456-YARR', 'People work_phone was updated';
    }

    Update_with_no_people_installed: {
        local $Socialtext::MassAdd::Has_People_Installed = 0;
        my @successes;
        my @failures;
        my $mass_add = Socialtext::MassAdd->new(
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        $mass_add->from_csv($PIRATE_CSV);
        is_deeply \@successes, ['No changes for user guybrush'],
            'success message ok';
        is_deeply \@failures, [], 'no failure messages';
    }
}

Quoted_csv: {
    local $Socialtext::User::Users{lechuck} = undef;
    my $quoted_csv = <<"EOT";
username,email_address,first_name,last_name,password,position,company,location,work_phone,mobile_phone,home_phone
"lechuck","ghost\@lechuck.example.com","Ghost Pirate","LeChuck","my_password","Ghost","Ghost Pirates Inc","Netherworld","","",""
guybrush,guybrush\@example.com,Guybrush,Threepwood,my_password,Captain,Pirates R. Us,High Seas,123-456-YARR,,123-HIGH-SEA
EOT
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($quoted_csv);
    is_deeply \@successes, ['Added user lechuck', 'Added user guybrush'], 'success message ok';
    is_deeply \@failures, [], 'no failure messages';
}

Csv_field_order_unimportant: {
    my $ODD_ORDER_CSV = <<'EOT';
last_name,first_name,username,email_address
Threepwood,Guybrush,guybrush,guybrush@example.com
EOT

    clear_log();

    # set up a fake User so we don't get a mocked one
    local $Socialtext::User::Users{guybrush} = undef;

    # set up the MassAdd-er
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );

    # try to add the user
    $mass_add->from_csv($ODD_ORDER_CSV);

    # make sure we were able to add the user
    is_deeply \@successes, ['Added user guybrush'], 'success message ok';
    is_deeply \@failures, [], 'no failure messages';
}

Contains_utf8: {
    local $Socialtext::User::Users{yamadat} = undef;
    my $utf8_csv = <<'EOT';
username,email_address,first_name,last_name,password,position,company,location,work_phone,mobile_phone,home_phone
yamadat,yamadat@example.com,太郎,山田,パスワード太,社長,日本電気株式会社,location,+81 3 3333 4444,+81 70 1234 5678,
EOT
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($utf8_csv);
    is_deeply \@successes, ['Added user yamadat'], 'success message ok, with utf8';
    is_deeply \@failures, [], 'no failure messages, with utf8';
}

Bad_email_address: {
    local $Socialtext::User::Users{lechuck} = undef;
    my $bad_csv = $PIRATE_CSV . <<'EOT';
lechuck,example.com,Ghost Pirate,LeChuck,my_password,Ghost,Ghost Pirates Inc,Netherworld,,,
EOT
    clear_log();
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($bad_csv);
    is_deeply \@successes, ['Added user guybrush'], 'success message ok';
    is_deeply \@failures,
        ['Line 3: example.com is not a valid email address'],
        'correct failure message';
    logged_like 'error',
        qr/\QLine 3: example.com is not a valid email address/,
        '... message also logged';
}

Duplicate_email_address: {
    # use a duplicate e-mail address (one already in use)
    (my $csv = $PIRATE_CSV) =~ s/guybrush@/duplicate@/;
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($csv);
    is_deeply \@successes, [], 'user was not added';
    is_deeply \@failures, ['Line 2: The email address you provided (duplicate@example.com) is already in use.'], 'correct failure message';
}

No_password_causes_email_to_be_sent: {
    # strip out the password from the csv line
    (my $csv = $PIRATE_CSV) =~ s/my_password//;
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($csv);
    is_deeply \@successes, ['Added user guybrush'], 'success message ok';
    is_deeply \@failures, [], 'no failure messages';
    is delete $Socialtext::User::Confirmation_info{guybrush}, 0,
        'confirmation is set';
    is delete $Socialtext::User::Sent_email{guybrush}, 1,
        'confirmation email sent';
}

Bad_password: {
    # Change the password to something too small
    (my $csv = $PIRATE_CSV) =~ s/my_password/pw/;
    clear_log();
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($csv);
    is_deeply \@successes, [], 'user was not added';
    is_deeply \@failures,
        ['Line 2: Passwords must be at least 6 characters long.'],
        'correct failure message';
    logged_like 'error', qr/Passwords must be at least 6 characters long/, '... message also logged';
}

Create_user_with_no_people_installed: {
    local $Socialtext::MassAdd::Has_People_Installed = 0;
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($PIRATE_CSV);
    is_deeply \@successes, ['Added user guybrush'], 'success message ok';
    is_deeply \@failures, [], 'no failure messages';
    is delete $Socialtext::User::Confirmation_info{guybrush}, undef,
        'confirmation is not set';
    is delete $Socialtext::User::Sent_email{guybrush}, undef,
        'confirmation email not sent';
}

Missing_username: {
    my $bad_csv = $PIRATE_CSV . <<'EOT';
,ghost@lechuck.example.com,Ghost Pirate,LeChuck,password,Ghost,Ghost Pirates Inc,Netherworld,,,
EOT
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($bad_csv);
    is_deeply \@successes, ['Added user guybrush'], 'success message ok';
    is_deeply \@failures,
        ['Line 3: username is a required field, but it is not present.'],
        'correct failure message';
}

Missing_email: {
    my $bad_csv = $PIRATE_CSV . <<'EOT';
lechuck,,Ghost Pirate,LeChuck,password,Ghost,Ghost Pirates Inc,Netherworld,,,
EOT
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($bad_csv);
    is_deeply \@successes, ['Added user guybrush'], 'success message ok';
    is_deeply \@failures,
        ['Line 3: email is a required field, but it is not present.'],
        'correct failure message';
}

Bogus_csv: {
    my $bad_csv = <<"EOT";
username,email_address,first_name,last_name,password,position,company,location,work_phone,mobile_phone,home_phone
This line isn't CSV but we're going to try to parse/process it anyways
lechuck\tghost\@lechuck.example.com\tGhost Pirate\tLeChuck\tpassword\tGhost\tGhost Pirates Inc\tNetherworld\t\t\t
guybrush,guybrush\@example.com,Guybrush,Threepwood,password,Captain,Pirates R. Us,High Seas,123-456-YARR,,123-HIGH-SEA
EOT
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($bad_csv);
    is_deeply \@failures,
        ['Line 2: could not be parsed (missing fields).  Skipping this user.',
         'Line 3: could not be parsed (missing fields).  Skipping this user.',
        ],
        'correct failure message';
    is_deeply \@successes, ['Added user guybrush'], 'continued on to add next user';
}

Fields_for_account: {
    no warnings 'redefine', 'once';
    local *Socialtext::People::Fields::new = sub { "dummy" };
    my $acct = Socialtext::Account->Default;
    my $fields = Socialtext::MassAdd->ProfileFieldsForAccount($acct);
    is $fields, "dummy";
}

my $FLEET_CSV = <<'EOT';
username,email_address,first_name,last_name,password,position,company,location,work_phone,mobile_phone,home_phone
guybrush,guybrush@example.com,Guybrush,Threepwood,password,Captain,Pirates R. Us,High Seas,123-456-YARR,mobile1,123-HIGH-SEA
bluebeard,bluebeard@example.com,Blue,Beard,password,Captain,Pirates R. Us,High Seas,123-456-YARR,mobile2,123-HIGH-SEA
EOT

Add_multiple_users_failure: {
    @Socialtext::People::Profile::Saved = ();
    local @Socialtext::People::Fields::UneditableNames = qw/mobile_phone/;

    # Explicitly set this user to undef, so we don't return a default mocked user
    $Socialtext::User::Users{guybrush} = undef;
    $Socialtext::User::Users{bluebeard} = undef;
    clear_log();
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($FLEET_CSV);
    is_deeply \@successes, ['Added user guybrush','Added user bluebeard'], 'success message ok';
    logged_like 'info', qr/Added user guybrush/, '... message also logged';
    logged_like 'info', qr/Added user bluebeard/, '... message also logged';
    is scalar(@failures), 1, 'only one error message per field updating failure';
    like $failures[0],
        qr/Profile field "mobile_phone" could not be updated/,
        '... correct failure message';

    my $profile1 = shift @Socialtext::People::Profile::Saved;
    isnt $profile1->{mobile_phone}, 'mobile1';
    my $profile2 = shift @Socialtext::People::Profile::Saved;
    isnt $profile2->{mobile_phone}, 'mobile2';
}

Missing_username_in_csv_header: {
    my $BOGUS_CSV = <<'EOT';
email_address,first_name,last_name,password
guybrush@example.com,Guybrush,Threepwood,guybrush_password
ghost@lechuck.example.com,Ghost Pirate,LeChuck,lechuck_password
EOT

    clear_log();

    # set up the MassAdd-er
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );

    # try to add the user
    $mass_add->from_csv($BOGUS_CSV);

    # make sure we failed, and *why*
    is scalar @successes, 0,
        'failed to add User(s) when missing username in CSV header';
    is_deeply \@failures,
        [
        'Line 1: could not be parsed.  The file was missing the following required fields (username).  The file must have a header row listing the field headers.'
        ], '... correct failure message';
    is scalar(@failures), 1, '... and ONLY ONE error message recorded';
}

Missing_email_in_csv_header: {
    my $BOGUS_CSV = <<'EOT';
username,first_name,last_name
guybrush,Guybrush,Threepwood
lechuck,Ghost Pirate,LeChuck
EOT

    clear_log();

    # set up the MassAdd-er
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );

    # try to add the user
    $mass_add->from_csv($BOGUS_CSV);

    # make sure we failed, and *why*
    is scalar @successes, 0,
        'failed to add User(s) when missing email address in CSV header';
    is_deeply \@failures,
        [
        'Line 1: could not be parsed.  The file was missing the following required fields (email_address).  The file must have a header row listing the field headers.'
        ], '... correct failure message';
    is scalar(@failures), 1, '... and ONLY ONE error message recorded';
}

Missing_csv_header: {
    my $BOGUS_CSV = <<'EOT';
guybrush,guybrush@example.com,Guybrush,Threepwood,guybrush_password
lechuck,ghost@lechuck.example.com,Ghost Pirate,LeChuck,lechuck_password
EOT

    clear_log();

    # set up the MassAdd-er
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );

    # try to add the user
    $mass_add->from_csv($BOGUS_CSV);

    # make sure we failed, and *why*
    is scalar @successes, 0, 'failed to add User(s) when missing CSV header';
    is_deeply \@failures,
        [
        'Line 1: could not be parsed.  The file was missing the following required fields (username, email_address).  The file must have a header row listing the field headers.'
        ], '... correct failure message';
    is scalar(@failures), 1, '... and ONLY ONE error message recorded';
}

Csv_header_has_more_columns_than_data: {
    my $BOGUS_CSV = <<'EOT';
username,email_address,first_name,last_name,password
guybrush,guybrush@example.com,Guybrush,Threepwood
lechuck,ghost@lechuck.example.com,Ghost Pirate,LeChuck
EOT

    clear_log();

    # set up the MassAdd-er
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );

    # try to add the user
    $mass_add->from_csv($BOGUS_CSV);

    # make sure we failed, and *why*
    is scalar @successes, 0,
        'failed to add User(s) with missing data columns';
    is_deeply \@failures,
        [
        'Line 2: could not be parsed (missing fields).  Skipping this user.',
        'Line 3: could not be parsed (missing fields).  Skipping this user.'
        ],
        '... correct failure messages';
    is scalar(@failures), 2, '... one error message per User failure';
}

Csv_header_has_less_columns_than_data: {
    my $BOGUS_CSV = <<'EOT';
username,email_address,first_name,last_name
guybrush,guybrush@example.com,Guybrush,Threepwood,guybrush_password
lechuck,ghost@lechuck.example.com,Ghost Pirate,LeChuck,lechuck_password
EOT

    clear_log();

    # Set up fake Users, so that we don't get mocked ones by accident
    local $Socialtext::User::Users{guybrush} = undef;
    local $Socialtext::User::Users{lechuck}  = undef;

    # set up the MassAdd-er
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );

    # try to add the user
    $mass_add->from_csv($BOGUS_CSV);

    # make sure we failed, and *why*
    is scalar @successes, 0,
        'failed to add User(s) with *extra* data columns';
    is_deeply \@failures,
        [
        'Line 2: could not be parsed (extra fields).  Skipping this user.',
        'Line 3: could not be parsed (extra fields).  Skipping this user.'
        ],
        '... correct failure messages';
    is scalar(@failures), 2, '... one error message per User failure';
}

Csv_header_cleanup: {
    # CSV with:
    #   a)  CamelCase headers,
    #   b)  Leading/trailing whitespace (which should be ignored)
    #   c)  Embedded whitespace (which should be turned into "_"s)
    my $CAMEL_CSV = <<'EOT';
Username , Email Address , First Name , Last Name , Password, Position , Company , Location
guybrush,guybrush@example.com,Guybrush,Threepwood,my_password,Captain,Pirates R. Us,High Seas
EOT

    clear_log();

    # Set up a fake User, so we don't get a mocked one by accident.
    local $Socialtext::User::Users{guybrush} = undef;

    # create a fake Profile so we can capture/verify the changes (and make
    # sure that they matched up correctly with the field names).
    local $Socialtext::People::Profile::Profiles{1}
        = Socialtext::People::Profile->new(
            position => 'Chef',
            company  => 'Scumm Bar',
            location => 'Monkey Island',
        );

    # set up the MassAdd-er
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );

    # add the user
    $mass_add->from_csv($CAMEL_CSV);

    # make sure the User got added ok, and that the Profile was updated
    # properly
    is_deeply \@successes, ['Added user guybrush'], 'success message ok';
    is_deeply \@failures, [], 'no failure messages';

    my $profile = $Socialtext::People::Profile::Profiles{1};
    is $profile->get_attr('position'), 'Captain',       'People position was updated';
    is $profile->get_attr('company'),  'Pirates R. Us', 'People company was updated';
    is $profile->get_attr('location'), 'High Seas',     'People location was updated';
}
