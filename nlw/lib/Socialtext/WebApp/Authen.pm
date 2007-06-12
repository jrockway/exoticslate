# @COPYRIGHT@
package Socialtext::WebApp;
use strict;
use warnings;

use Email::Valid;
use Socialtext;
use Socialtext::AppConfig;
use Socialtext::Log 'st_log';
use Socialtext::Authen;
use Socialtext::Apache::User;
use Socialtext::User;

sub login : Action {
    my $self = shift;

    my $username = $self->args->{username};

    my $user_check = (Socialtext::WebApp->username_label() eq 'Email Address' ? 
                      Email::Valid->address($username) : 
                      ($username =~ /\w/) );

    unless ( $user_check ) {

        $username = '' unless defined $username;

        $self->_login_error(
            "Invalid login: '$username'",
            {
                type => 'invalid_username',
                args => { username => $username }
            }
        );
    }

    my $auth = Socialtext::Authen->new();
    my $user = Socialtext::User->new( username => $username );

    # XXX: Until we get over the stupid reliance on email addresses everywhere
    if ( $user && !$user->email_address ) {
        $self->_login_error(
            "User is from the 19th century?!: '$username'",
            {
                type => 'invalid_email',
                args => { username => $username }
            }
        );
    }

    if ( $user and $user->requires_confirmation() ) {
        $self->_login_error(
            "$username has not yet confirmed their email address.",
            { type => 'requires_confirmation',
              args => {
                  email_address => $user->email_address,
                  username      => $username,
                  redirect_to   => $self->args->{redirect_to},
              },
            },
        );
    }

    unless (
        $auth->check_password(
            username => $username,
            password => $self->args->{password},
        )
      ) {
        $self->_login_error(
            "Invalid email address or password for '$username'",
            { type => 'wrong_email_or_password' },
        );
    }


    my $expire = $self->args->{remember} ? '+12M' : '';

    Socialtext::Apache::User::set_login_cookie( $self->apache_req, $user->user_id,
        $expire );


    $user->record_login();
    my $expected_destination = $self->args->{redirect_to} || '/';

    st_log->info( "LOGIN: "
            . $user->email_address()
            . " destination: "
            . $expected_destination );

    $self->redirect( uri => $expected_destination );
}

sub _login_error {
    my $self    = shift;
    my $log_msg = shift;
    my $error   = shift;

    $self->apache_req->log_reason($log_msg);

    my $args     = $self->args;
    my $redirect = delete $args->{redirect_to};

    $self->_handle_error(
        error     => $error,
        path      => '/nlw/login.html',
        query     => { redirect_to => $redirect },
        save_args => $args,
    );
}

sub logout : Action {
    my $self = shift;

    Socialtext::Apache::User::unset_login_cookie();

    $self->redirect( uri => $self->args->{redirect_to} || '/nlw/login.html' );
}

sub forgot_password : Action {
    my $self = shift;

    my $user = Socialtext::User->new( username => $self->args->{username} );
    unless ( $user ) {
        $self->_handle_error(
            error => {
                type => 'username_does_not_exist',
                args => { username => $self->args->{username} },
            },
            path      => '/nlw/forgot_password.html',
            save_args => $self->args,
        );
    }

    $user->set_confirmation_info( is_password_change => 1 );
    $user->send_password_change_email();

    $self->session->add_message( 'An email with instructions on changing your'
                                 . ' password has been sent to ' . $user->username() . '.');

    $self->session->save_args( username => $user->username() );

    $self->redirect(
        path  => '/nlw/login.html',
        query => { redirect_to => $self->args->{redirect_to} },
    );
}

sub register : Action {
    my $self = shift;

    my $email_address = $self->args->{email_address};
    my $user = Socialtext::User->new( email_address => $email_address );

    if ($user) {
        if ( $user->requires_confirmation() ) {
            $self->session->add_error( {
                type => 'requires_confirmation',
                args => {
                   email_address => $email_address,
                   redirect_to   => $self->args->{redirect_to},
               },
            } );

            $self->redirect(
                path  => '/nlw/login.html',
                query => { redirect_to => $self->args->{redirect_to} },
            );
        }
        elsif ( $user->has_valid_password() ) {
            $self->session->add_message("A user with this email address ($email_address) already exists.");
            $self->session->save_args( email_address => $email_address );

            $self->redirect(
                path  => '/nlw/login.html',
                query => { redirect_to => $self->args->{redirect_to} },
            );
        }
    }

    unless ( $self->args->{password} eq $self->args->{password2} ) {
        $self->session->add_error('The passwords you provided did not match.');
    }

    eval {
        if ($user) {
            $user->update_store(
                password      => $self->args->{password},
                first_name    => $self->args->{first_name},
                last_name     => $self->args->{last_name},
            );
        }
        else {
            $user =
                Socialtext::User->create(
                    username      => $email_address,
                    email_address => $email_address,
                    password      => $self->args->{password},
                    first_name    => $self->args->{first_name},
                    last_name     => $self->args->{last_name},
                );
        }
    };
    if ( my $e = Exception::Class->caught('Socialtext::Exception::DataValidation') ) {
        # We don't show them "Username is required" since that field
        # is not on the form.
        $self->session->add_error($_) for grep { ! /Username.+required/i } $e->messages;
    }
    elsif ( $@ ) {
        die $@;
    }

    if ( $self->session->has_errors ) {
        my $redirect = delete $self->args->{redirect_to};

        $self->session->save_args( %{ $self->args } );

        $self->redirect(
            path  => '/nlw/register.html',
            query => { redirect_to => $redirect },
        );
    }

    $user->set_confirmation_info();
    $user->send_confirmation_email();

    $self->session->add_message("An email confirming your registration has been sent to $email_address.");
    $self->redirect(
        path  => '/nlw/login.html',
        query => { redirect_to => $self->args->{redirect_to} },
    );
}

sub resend_confirmation : Action {
    my $self = shift;

    my $email_address = $self->args->{email_address};
    my $user = Socialtext::User->new( email_address => $email_address );

    unless ( $user->requires_confirmation ) {
        $self->session->add_message( "The email address for $email_address has already been confirmed." );
        $self->redirect( path  => '/nlw/login.html' );
    }

    $user->set_confirmation_info();
    $user->send_confirmation_email();

    $self->session->add_error("The confirmation email has been resent."
                              . " Please follow the link in this email to activate your account.");
    $self->session->save_args( email_address => $email_address );
    $self->redirect(
        path  => '/nlw/login.html',
        query => { redirect_to => $self->args->{redirect_to} },
    );
}

sub confirm_email : Action {
    my $self = shift;

    my $hash = $self->args->{hash};

    $self->redirect( path  => '/nlw/login.html' )
        unless $hash;

    my $user = Socialtext::User->new( email_confirmation_hash => $hash );

    unless ($user) {
        $self->session->add_error("The given confirmation URL does not match any pending confirmations.");
        $self->redirect( path  => '/nlw/login.html' );
    }

    if ( $user->confirmation_has_expired ) {
        $user->set_confirmation_info();

        if ( $user->confirmation_is_for_password_change() ) {
            $user->send_password_change_email();
        }
        else {
            $user->send_confirmation_email();
        }

        $self->session->add_error("The confirmation URL you used has expired. A new one will be sent.");
        $self->redirect(
            path  => '/nlw/login.html',
            query => { redirect_to => $self->args->{redirect_to} },
        );
    }

    if ( $user->confirmation_is_for_password_change() or not $user->has_valid_password ) {
        $self->redirect(
            path  => '/nlw/choose_password.html',
            query => {
                hash        => $self->args->{hash},
                redirect_to => $self->args->{redirect_to},
            },
        );
    }

    $user->confirm_email_address();

    my $address = $user->email_address;
    $self->session->add_message("Your email address, $address, has been confirmed. Please login.");
    $self->session->save_args( username => $user->username );
    $self->redirect(
        path  => '/nlw/login.html',
        query => { redirect_to => $self->args->{redirect_to} },
    );
}

sub choose_password : Action {
    my $self = shift;

    my $hash = $self->args->{hash};

    $self->redirect( path  => '/nlw/login.html' )
        unless $hash;

    my $user = Socialtext::User->new( email_confirmation_hash => $hash );

    unless ($user) {
        $self->redirect(
            path  => '/nlw/login.html',
            query => { redirect_to => $self->args->{redirect_to} },
        );
    }

    unless ( $self->args->{password} eq $self->args->{password2} ) {
        $self->session->add_error('The passwords you provided did not match.');
    }

    if ( my @errors = Socialtext::User->ValidatePassword(
                         password => $self->args->{password} ) ) {
        $self->session()->add_error($_) for @errors;
    }
    else {
        eval { $user->update_store( password => $self->args->{password} ) };
    }

    if ( my $e = Exception::Class->caught('Socialtext::Exception::DataValidation') ) {
        $self->session()->add_error($_) for $e->messages();
    }
    elsif ( $@ ) {
        die $@;
    }

    if ( $self->session()->has_errors() ) {
        $self->redirect(
            path  => '/nlw/choose_password.html',
            query => {
                hash        => $self->args->{hash},
                redirect_to => $self->args->{redirect_to},
            },
        );
    }

    $user->confirm_email_address();

    $self->session()->add_message("Your password has been set and you can now login");
    $self->session()->save_args( username => $user->username() );
    $self->redirect(
        path  => '/nlw/login.html',
        query => { redirect_to => $self->args->{redirect_to} },
    );
}


1;
