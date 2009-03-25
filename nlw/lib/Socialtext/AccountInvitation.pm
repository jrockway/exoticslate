# @COPYRIGHT@
package Socialtext::AccountInvitation;

use strict;
use warnings;

our $VERSION = '0.01';

use Socialtext::AppConfig;
use Socialtext::TT2::Renderer;
use Socialtext::URI;
use Socialtext::User;
use Socialtext::l10n qw(system_locale loc);
use Socialtext::EmailSender::Factory;
=pod

=over 4

=item * account => $account

=item * from_user => $from_user

=item * invitee   => $invitee_address

=item * extra_text => $extra_text

=item * viewer    => $viewer

=back

=cut

sub new {
    my $class = shift;
    my $self = { @_ };
    bless $self, $class;
    return $self;
}

sub send {
    my $self = shift;
    $self->_invite_one_user( );
}

sub _invite_one_user {
    my $self = shift;

    my $user = Socialtext::User->new(
        email_address => $self->{invitee}
    );
    my $acct = $self->{account};
    $user ||= Socialtext::User->create(
        username => $self->{invitee},
        email_address => $self->{invitee},
        first_name => $self->{invitee_first_name},
        last_name => $self->{invitee_last_name},
        created_by_user_id => $self->{from_user}->user_id,
        primary_account_id => $acct->account_id,
    );

    $user->set_confirmation_info()
        unless $user->has_valid_password();

    $user->primary_account($acct);

    $self->_log_action( "INVITE_USER_ACCOUNT", $user->email_address );
    $self->invite_notify( $user );
}

sub invite_notify {
    my $self       = shift;
    my $user       = shift;
    my $extra_text = $self->{extra_text};
    my $account    = $self->{account};

    my $template_dir = 'st'; # XXX - Per-account OpenID?

    my $subject = loc("I'm inviting you into the [_1] account", $account->name);

    my $renderer = Socialtext::TT2::Renderer->instance();

    my $forgot_pw_uri
        = Socialtext::URI::uri( path => '/nlw/forgot_password.html' );

    my $app_name = Socialtext::AppConfig->is_appliance()
        ? 'Socialtext Appliance'
        : 'Socialtext';

    my %vars = (
        username              => $user->username,
        requires_confirmation => $user->requires_confirmation,
        confirmation_uri      => $user->confirmation_uri || '',
        host                  => Socialtext::AppConfig->web_hostname(),
        account_name          => $account->name,
        account_uri           => Socialtext::URI::uri( path => '/' ),
        inviting_user         => $self->{from_user}->best_full_name,
        app_name              => $app_name,
        forgot_password_uri   => $forgot_pw_uri,
        appconfig             => Socialtext::AppConfig->instance(),
    );

    my $text_body = $renderer->render(
        template => "email/$template_dir/account-invitation.txt",
        vars     => {
            %vars,
            extra_text => $extra_text,
        }
    );

    my $html_body = $renderer->render(
        template => "email/account-invitation.html",
        vars     => {
            %vars,
            account_invitation_body => "email/$template_dir/account-invitation-body.html",
            extra_text =>
                     $self->{viewer} ? $self->{viewer}->process( $extra_text || '' ) :
                                       $extra_text,
        }
    );

    open FH, '>/tmp/2';
    print FH $html_body;
    close FH;

    my $locale = system_locale();
    my $email_sender = Socialtext::EmailSender::Factory->create($locale);
    $email_sender->send(
        from      => $self->{from_user}->name_and_email,
        to        => $user->email_address,
        subject   => $subject,
        text_body => $text_body,
        html_body => $html_body,
    );
}

sub _log_action {
    my $self = shift;
    my $action = shift;
    my $extra  = shift;
    my $account = $self->{account}->name;
    my $page_name = '';
    my $user_name = $self->{from_user}->user_id;
    my $log_msg = "$action : $account : $page_name : $user_name";
    if ($extra) {
        $log_msg .= " : $extra";
    }
    Socialtext::Log->new()->info("$log_msg");
}

1;

1;
