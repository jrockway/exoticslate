package Socialtext::MassAdd;
# @COPYRIGHT@
use strict;
use warnings;
use Text::CSV_XS;
use Socialtext::Encode;
use Socialtext::Log qw(st_log);
use Socialtext::User;
use Socialtext::l10n qw/loc/;

our $Has_People_Installed;

BEGIN {
    eval "require Socialtext::People::Profile";
    $Has_People_Installed = !$@;
}

sub users {
    my $class   = shift;
    my %opts    = @_;
    my $csv     = delete $opts{csv}     or die "csv is mandatory!";
    my $pass_cb = delete $opts{pass_cb} or die "pass_cb is mandatory!";
    my $fail_cb = delete $opts{fail_cb} or die "fail_cb is mandatory!";
    my $account = delete $opts{account};

    my @required_fields = qw/username email_address/;
    my @user_fields = qw/first_name last_name password/;
    my @profile_fields
        = qw/position company location work_phone mobile_phone home_phone/;

    # make sure that we're working with UTF8; if we don't set this then
    # Text::CSV_XS isn't going to parse UTF8 properly
    $csv = Socialtext::Encode::ensure_is_utf8($csv);
    my $parser = Text::CSV_XS->new();
    my @lines = split "\n", $csv;
    my $line = 0;
  LINE:
    for my $user_record (@lines) {
        $line++;

        # parse the next line, choking if its not valid.
        my $parsed_ok = $parser->parse($user_record);
        my @fields    = $parser->fields();
        unless ($parsed_ok and (scalar @fields >= scalar @required_fields)) {
            my $msg = loc("Line [_1]: could not be parsed.  Skipping this user.", $line);
            st_log->error($msg);
            $fail_cb->($msg);
            next LINE;
        }

        # extract field data from the parsed line
        my ($username, $email, $first_name, $last_name, $password, @profile)
            = map { defined $_ ? $_ : '' } @fields;
        my @userdata = ($first_name, $last_name, $password);

        # sanity check the parsed data, to make sure that fields we *know* are
        # required are really present
        unless ($username) {
            my $msg = loc("Line [_1]: [_2] is a required field, but it is not present.", $line, 'username');
            st_log->error($msg);
            $fail_cb->($msg);
            next LINE;
        }
        unless ($email) {
            my $msg = loc("Line [_1]: [_2] is a required field, but it is not present.", $line, 'email');
            st_log->error($msg);
            $fail_cb->($msg);
            next LINE;
        }
        if (length($password)) {
            my $result
                = Socialtext::User->ValidatePassword(password => $password);
            if ($result) {
                my $msg = loc("Line [_1]: [_2]", $line, $result);
                st_log->error($msg);
                $fail_cb->($msg);
                next LINE;
            }
        }

        # see if we've got an existing record for this user, and add/update as
        # necessary.
        my $user;
        my $changed_user = 0;
        my $added_user = 0;
        eval { $user = Socialtext::User->Resolve($username) };
        if ($user) {
            # Update the user's primary account if one is specified
            $user->primary_account($account) if $account;
        }
        else {
            eval {
                $user = Socialtext::User->create(
                    username      => $username,
                    email_address => $email,
                    ($password ? (password => $password) : ()),
                    first_name    => $first_name,
                    last_name     => $last_name,
                    ($account ? (primary_account_id => $account->account_id) : ()),
                );
                $added_user++;
            };
            my $err = $@;
            if (my $e = Exception::Class->caught('Socialtext::Exception::DataValidation')) {
                foreach my $m ($e->messages) {
                    my $msg = loc("Line [_1]: [_2]", $line, $m);
                    st_log->error($msg);
                    $fail_cb->($msg);
                }
                next LINE;
            }
            elsif ($err) {
                st_log->error($err);
                $fail_cb->($err);
                next LINE;
            }

            # Send the user a confirmation email, if they don't have a pw
            unless ( $user->has_valid_password ) {
                $user->set_confirmation_info( is_password_change => 0 );
                $user->send_confirmation_email();
            }
        }

        if ($user->can_update_store) {
            for (my $i = 0; $i < @user_fields; $i++) {
                my $field = $user_fields[$i];
                my $value = $userdata[$i];
                my $uptodate = sub { $user->$field() eq $value };
                if ($field eq 'password') {
                    $uptodate = sub { $user->password_is_correct($value) };
                }
                if (length($userdata[$i]) and not $uptodate->()) {
                    $user->update_store( $field => $value );
                    $changed_user++;
                }
            }
        }

        if ($Has_People_Installed) {
            my $p = Socialtext::People::Profile->GetProfile($user, 1);
            for (my $i = 0; $i < @profile_fields; $i++) {
                my $value = $profile[$i];
                next unless $value;
                my $field = $profile_fields[$i];
                next if ($p->$field() || '') eq $value;
                $p->$field($value);
                $changed_user++;
            }
            $p->save() if ($changed_user);
        }
        if ($added_user) {
            my $msg = loc("Added user [_1]", $username);
            st_log->info($msg);
            $pass_cb->($msg);
        }
        elsif ($changed_user) {
            my $msg = loc("Updated user [_1]", $username);
            st_log->info($msg);
            $pass_cb->($msg);
        }
        else {
            my $msg = loc("No changes for user [_1]", $username);
            st_log->info($msg);
            $pass_cb->($msg);
        }
    }
}

1;
