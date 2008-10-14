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
our @Required_fields = qw/username email_address/;
our @User_fields = qw/first_name last_name password/;
our @Profile_fields
    = qw/position company location work_phone mobile_phone home_phone/;

BEGIN {
    eval "require Socialtext::People::Profile";
    $Has_People_Installed = !$@;
}

sub new {
    my $self = bless {}, shift;
    my %opts = @_;
    $self->{pass_cb} = delete $opts{pass_cb} or die "pass_cb is mandatory!";
    $self->{fail_cb} = delete $opts{fail_cb} or die "fail_cb is mandatory!";
    $self->{account} = delete $opts{account};
    return $self;
}

sub from_csv {
    my $self = shift;
    my $csv  = shift;

    # make sure that we're working with UTF8; if we don't set this then
    # Text::CSV_XS isn't going to parse UTF8 properly
    $csv = Socialtext::Encode::ensure_is_utf8($csv);
    my $parser = Text::CSV_XS->new();
    my @lines = split "\n", $csv;
    $self->{line} = 0;
    $self->{from_csv} = 1;

LINE:
    for my $user_record (@lines) {
        $self->{line}++;

        # parse the next line, choking if its not valid.
        my $parsed_ok = $parser->parse($user_record);
        my @fields    = $parser->fields();
        unless ($parsed_ok and (scalar @fields >= scalar @Required_fields)) {
            my $msg = loc("could not be parsed.  Skipping this user.");
            $self->_fail($msg);
            next LINE;
        }
        $self->_add_user(@fields);
    }
}

sub add_user {
    my $self = shift;
    my %args = @_;
    $self->_add_user(
        map { $args{$_} } (@Required_fields, @User_fields, @Profile_fields)
    );
}

sub _add_user {
    my $self = shift;

    # extract field data from the parsed line
    my ($username, $email, $first_name, $last_name, $password, @profile)
        = map { defined $_ ? $_ : '' } @_;
    my @userdata = ($first_name, $last_name, $password);

    # sanity check the parsed data, to make sure that fields we *know* are
    # required are really present
    unless ($username) {
        my $msg = loc("[_1] is a required field, but it is not present.", 'username');
        $self->_fail($msg);
        return; # used to be 'next LINE;'
    }
    unless ($email) {
        my $msg = loc("[_1] is a required field, but it is not present.", 'email');
        $self->_fail($msg);
        return; # used to be 'next LINE;'
    }
    if (length($password)) {
        my $result
            = Socialtext::User->ValidatePassword(password => $password);
        if ($result) {
            $self->_fail($result);
            return; # used to be 'next LINE;'
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
        $user->primary_account($self->{account}) if $self->{account};
    }
    else {
        eval {
            $user = Socialtext::User->create(
                username      => $username,
                email_address => $email,
                ($password ? (password => $password) : ()),
                first_name    => $first_name,
                last_name     => $last_name,
                ($self->{account} ? (primary_account_id => $self->{account}->account_id) : ()),
            );
            $added_user++;
        };
        my $err = $@;
        if (my $e = Exception::Class->caught('Socialtext::Exception::DataValidation')) {
            foreach my $m ($e->messages) {
                $self->_fail($m);
            }
            return; # used to be 'next LINE;'
        }
        elsif ($err) {
            $self->_fail($err);
            return; # used to be 'next LINE;'
        }

        # Send the user a confirmation email, if they don't have a pw
        unless ( $user->has_valid_password ) {
            $user->set_confirmation_info( is_password_change => 0 );
            $user->send_confirmation_email();
        }
    }

    if ($user->can_update_store) {
        for (my $i = 0; $i < @User_fields; $i++) {
            my $field = $User_fields[$i];
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
        my $p = Socialtext::People::Profile->GetProfile($user,
            no_recurse => 1);
        for (my $i = 0; $i < @Profile_fields; $i++) {
            my $value = $profile[$i];
            next unless $value;
            my $field = $Profile_fields[$i];
            next if ($p->$field() || '') eq $value;
            $p->$field($value);
            $changed_user++;
        }
        $p->save() if ($changed_user);
    }
    if ($added_user) {
        my $msg = loc("Added user [_1]", $username);
        $self->_pass($msg);
    }
    elsif ($changed_user) {
        my $msg = loc("Updated user [_1]", $username);
        $self->_pass($msg);
    }
    else {
        my $msg = loc("No changes for user [_1]", $username);
        $self->_pass($msg);
    }
}

sub _pass {
    my $self = shift;
    my $msg = shift;
    st_log->info($msg);
    $self->{pass_cb}->($msg);
}

sub _fail {
    my $self = shift;
    my $msg = shift;
    $msg = loc("Line [_1]: ", $self->{line}) . $msg
        if ($self->{from_csv});
    st_log->error($msg);
    $self->{fail_cb}->($msg);
}

1;
