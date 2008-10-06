package Socialtext::WikiFixture::SocialBase;
# @COPYRIGHT@
use strict;
use warnings;
use Socialtext::Account;
use Socialtext::User;
use Test::More;
use LWP::Simple;

sub create_account {
    my $self = shift;
    my $name = shift;
    my $acct = Socialtext::Account->create(
        name => $name,
    );
    $acct->enable_plugin($_) for qw/people dashboard widgets socialcalc/;
    diag "Created account $name";
}

sub create_user {
    my $self = shift;
    my $email = shift;
    my $password = shift;
    my $account = shift;

    Socialtext::User->create(
        email_address => $email,
        username      => $email,
        password      => $password,
        (
            $account
            ? (primary_account_id =>
                    Socialtext::Account->new(name => $account)->account_id())
            : ()
        )
    );
    diag "Created user $email";
}

sub create_workspace {
    my $self = shift;
    my $name = shift;
    my $account = shift;

    my $ws = Socialtext::Workspace->new(name => $name);
    if ($ws) {
        diag "Workspace $name already exists";
        return
    }

    Socialtext::Workspace->create(
        name => $name, title => $name,
        (
            $account
            ? (account_id => Socialtext::Account->new(name => $account)
                ->account_id())
            : ()
        ),
        skip_default_pages => 1,
    );
    diag "Created workspace $name";
}

sub set_ws_permissions {
    my $self       = shift;
    my $workspace  = shift;
    my $permission = shift;

    my $ws = Socialtext::Workspace->new(name => $workspace);
    die "No such workspace $workspace" unless $ws;
    $ws->permissions->set( set_name => $permission );
    diag "Set workspace $workspace permission to $permission";
}

sub add_member {
    my $self = shift;
    my $email = shift;
    my $workspace = shift;

    my $ws = Socialtext::Workspace->new(name => $workspace);
    die "No such workspace $workspace" unless $ws;
    my $user = Socialtext::User->Resolve($email);
    die "No such user $email" unless $user;

    $ws->add_user( user => $user );
    diag "Added user $email to $workspace";
}

sub set_user_id {
    my $self = shift;
    my $var_name = shift;
    my $email = shift;

    my $user = Socialtext::User->Resolve($email);
    die "No such user $email" unless $user;
    $self->{$var_name} = $user->user_id;
    diag "Set variable $var_name to $self->{$var_name}";
}

sub set_account_id {
    my $self = shift;
    my $var_name = shift;
    my $acct_name = shift;

    my $acct = Socialtext::Account->new(name => $acct_name);
    die "No such user $acct_name" unless $acct;
    $self->{$var_name} = $acct->account_id;
    diag "Set variable $var_name to $self->{$var_name}";
}

1;
