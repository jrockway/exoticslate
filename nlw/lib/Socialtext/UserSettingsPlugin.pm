# @COPYRIGHT@
package Socialtext::UserSettingsPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use Class::Field qw( const field );
use Email::Address;
use Email::Valid;
use Socialtext::AppConfig;
use Socialtext::EmailSender::Factory;
use Socialtext::Permission qw( ST_ADMIN_WORKSPACE_PERM );
use Socialtext::TT2::Renderer;
use Socialtext::User;
use Socialtext::WorkspaceInvitation;
use Socialtext::URI;
use Socialtext::l10n qw( loc system_locale);

sub class_id {'user_settings'}
const cgi_class => 'Socialtext::UserSettings::CGI';
field 'users_new_ids';
field users_already_present => [];

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add( action => 'settings' );
    $registry->add( action => 'users_settings' );
    $registry->add( action => 'users_listall' );
    $registry->add( action => 'users_invitation' );
    $registry->add( action => 'users_invite' );
    $registry->add( action => 'users_search' );
}

# for backwards compat
sub settings {
    my $self = shift;
    $self->redirect('action=users_settings');
}

sub users_settings {
    my $self = shift;
    if ( $self->hub()->current_user()->is_guest() ) {
        Socialtext::Challenger->Challenge(
            type => 'settings_requires_account' );
    }

    $self->_update_current_user()
        if $self->cgi->Button;

    my $settings_section = $self->template_process(
        'element/settings/users_settings_section',
        user => $self->hub->current_user,
        $self->status_messages_for_template,
    );

    $self->screen_template('view/settings');
    return $self->render_screen(
        settings_table_id => 'settings-table',
        settings_section  => $settings_section,
        hub               => $self->hub,
        display_title     => loc('Users: My Settings'),
        pref_list         => $self->_get_pref_list,
    );
}

sub _update_current_user {
    my $self = shift;
    my $user = $self->hub->current_user;

    my %update;
    if (   $self->cgi->old_password
        or $self->cgi->new_password
        or $self->cgi->new_password_retype ) {
        $self->add_error(loc('Old password is incorrect'))
            unless $user->password_is_correct( $self->cgi->old_password );
        $self->add_error(loc('New passwords do not match'))
            unless $self->cgi->new_password eq
            $self->cgi->new_password_retype;

        return if $self->input_errors_found;

        $update{password} = $self->cgi->new_password;
    }

    $update{first_name} = $self->cgi->first_name;
    $update{last_name}  = $self->cgi->last_name;

    eval { $user->update_store(%update) };
    if ( my $e
        = Exception::Class->caught('Socialtext::Exception::DataValidation') )
    {
        $self->add_error($_) for $e->messages;
    }
    elsif ($@) {
        die $@;
    }

    return if $self->input_errors_found;

    $self->message(loc('Changes Saved'));
}

sub get_admins {
    my $self = shift;
    my $workspace = $self->hub->current_workspace;
    my @admins;
    my $users_with_roles = $workspace->users_with_roles();

    while ( my $tuple = $users_with_roles->next ) {
        my $user = $tuple->[0];
        my $role = $tuple->[1];
        if ( $role->name eq 'workspace_admin' ) {
            push( @admins, $user->email_address );
        }
    }
    return (@admins);
}

sub users_listall {
    my $self = shift;
    if ( $self->hub()->current_user()->is_guest() ) {
        Socialtext::Challenger->Challenge(
            type => 'settings_requires_account' );
    }

    $self->_update_users_in_workspace()
        if $self->cgi->Button;

    my @uwr = $self->hub->current_workspace->users_with_roles->all;
    my $settings_section = $self->template_process(
        'element/settings/users_listall_section',
        users_with_roles => \@uwr,
        $self->status_messages_for_template,
    );

    my $display_title =
        $self->hub->checker->check_permission('admin_workspace')
        ? loc('Users: Manage All Users')
        : loc('Users: List All Users');

    $self->screen_template('view/settings');
    return $self->render_screen(
        settings_table_id => 'settings-table',
        settings_section  => $settings_section,
        hub               => $self->hub,
        display_title     => $display_title,
        pref_list         => $self->_get_pref_list,
    );
}

sub _update_users_in_workspace {
    my $self = shift;
    $self->hub->assert_current_user_is_admin;


    my $ws = $self->hub->current_workspace;
    my %removed;
    for my $user_id ( $self->cgi->remove_user ) {
        my $user = Socialtext::User->new( user_id => $user_id );

        $ws->remove_user( user => $user );

        $removed{$user_id} = 1;
    }

    for my $user_id ( grep { !$removed{$_} } $self->cgi->reset_password ) {
        my $user = Socialtext::User->new( user_id => $user_id );

        $user->set_confirmation_info( is_password_change => 1 );
        $user->send_password_change_email();
    }

    my %should_be_admin = map { $_ => 1 } $self->cgi->should_be_admin;
    if ( keys %should_be_admin ) {

        my $users_with_roles
            = $self->hub->current_workspace->users_with_roles;

        while ( my $tuple = $users_with_roles->next ) {

            my $user = $tuple->[0];
            my $role = $tuple->[1];

            # REVIEW - this is a hack to prevent us from removing the
            # impersonator role from users in this loop. The real
            # solution is to replace the is/is not admin check with
            # something like a pull down or radio group which allows
            # for assigning of different roles.
            next if $role->name ne 'workspace_admin'
                and $role->name ne 'member';

            next if $should_be_admin{ $user->user_id() }
                and $ws->permissions->user_can(
                    user       => $user,
                    permission => ST_ADMIN_WORKSPACE_PERM,
                );

            next if not $should_be_admin{ $user->user_id() }
                and not $ws->permissions->user_can(
                    user       => $user,
                    permission => ST_ADMIN_WORKSPACE_PERM,
                );

            my $is_selected = $user->workspace_is_selected(
                workspace => $self->hub()->current_workspace() );

            if ( $should_be_admin{ $user->user_id } ) {
                $ws->assign_role_to_user(
                    user        => $user,
                    role        => Socialtext::Role->WorkspaceAdmin(),
                    is_selected => $is_selected,
                );
            }
            else {
                $ws->assign_role_to_user(
                    user        => $user,
                    role        => Socialtext::Role->Member(),
                    is_selected => $is_selected,
                );
            }
        }
    }
    else {
        $self->add_warning(loc("Can't remove privileges of the last admin"));
    }

    $self->message(loc('Changes Saved'));

    return;
}

# XXX this method doesn't seem to have test coverage
sub users_invitation {
    my $self = shift;
    if ( !$self->hub->checker->check_permission('request_invite') ) {
        $self->hub->assert_current_user_is_admin;
    }

    my $ws                            = $self->hub->current_workspace;
    my $restrict_invitation_to_search = $ws->restrict_invitation_to_search;
    my $invitation_filter             = $ws->invitation_filter;
    my $template_dir                  = $ws->invitation_template;
    my $template;
    my $action;

    if ($restrict_invitation_to_search) {
        $template = 'element/settings/users_invite_search_section';
        $action   = 'users_search';
    }
    elsif ( my $screen = Socialtext::AppConfig->custom_invite_screen() ) {
        $template = 'element/settings/users_invite_' . $screen;
        $action   = $screen;
    }
    else {
        $template = 'element/settings/users_invite_section';
        $action   = 'users_invite';
    }

    $self->hub->action(
        $restrict_invitation_to_search ? 'users_search' : $action );

    my $settings_section = $self->template_process(
        $template,
        invitation_filter         => $invitation_filter,
        workspace_invitation_body =>
            "email/$template_dir/workspace-invitation-body.html",
        $self->status_messages_for_template,
    );

    $self->screen_template('view/settings');
    return $self->render_screen(
        settings_table_id => 'settings-table',
        settings_section  => $settings_section,
        hub               => $self->hub,
        display_title     => loc('Users: Invite New Users'),
        pref_list         => $self->_get_pref_list,
    );
}


sub users_invite {
    my $self = shift;
    if ( !$self->hub->checker->check_permission('request_invite') ) {
        $self->hub->assert_current_user_is_admin;
    }

    my @emails;
    my @invalid;
    if ( my $ids = $self->cgi->users_new_ids ) {
        my @lines = $self->_split_email_addresses( $ids );

        unless (@lines) {
            $self->add_error(loc("No email addresses specified"));
            return;
        }

        for my $line (@lines) {
            my ( $email, $first_name, $last_name )
              = $self->_parse_email_address($line);
            unless ($email) {
                push @invalid, $line;
                next;
            }

            push @emails, {
                email_address => $email,
                first_name => $first_name,
                last_name => $last_name,
            }
        }
    }
    else
    {
        push @invalid, loc("No email addresses specified");
    }

    my $html = $self->_invite_users(\@emails, \@invalid);
    return $html if $html;
}

sub users_search {
    my $self = shift;
    my $filter = $self->hub->current_workspace->invitation_filter();
    my $template_dir = $self->hub->current_workspace->invitation_template();
    if ( !$self->hub->checker->check_permission('request_invite') ) {
        $self->hub->assert_current_user_is_admin;
    }

    my @users;

    if ( $self->cgi->Button ) {
        if ( $self->cgi->Button eq 'Invite' && $self->cgi->email_addresses ) {
            my @emails = map {+{email_address=>$_}} $self->cgi->email_addresses;
            my @invalid;
            my $html = $self->_invite_users(\@emails, \@invalid);
            return $html if $html;
        }
    }

    if ( $self->cgi->user_search ) {
        @users = Socialtext::User->Search( $self->cgi->user_search );
    }

    if (@users && $filter) {
        @users = grep { $_ if ($_->{email_address} =~ qr/$filter/) } @users;
    }

    my $settings_section = $self->template_process(
        'element/settings/users_invite_search_section',
        invitation_filter => $filter,
        $self->status_messages_for_template,
        workspace_invitation_body     => "email/$template_dir/workspace-invitation-body.html",
        users => \@users,
        search_performed => 1,
    );

    $self->screen_template('view/settings');
    return $self->render_screen(
        settings_table_id => 'settings-table',
        settings_section  => $settings_section,
        hub               => $self->hub,
        display_title     => loc('Users: Invite New Users'),
        pref_list         => $self->_get_pref_list,
    );
}

sub _invite_users {
    my $self = shift;
    my ($emails, $invalid) = @_;
    my $filter = $self->hub->current_workspace->invitation_filter();

    my %users;
    my @present;
    for my $e (@{ $emails }) {
        my $email = $e->{email_address};
        if ($filter) {
            unless ( $email =~ qr/$filter/ ) {
                push @{ $invalid }, $email;
                next;
            }
        }
        next if $users{$email};

        my $user = Socialtext::User->new( email_address => $email );
        if (   $user
            && $self->hub->current_workspace->has_user( $user ) )
        {
            push @present, $email;
            next;
        }

        $users{$email} = {
            username      => $email,
            email_address => $email,
            first_name => $e->{first_name},
            last_name => $e->{last_name},
        };
    }

    my $extra_invite_text = $self->cgi->append_invitation ?
                            $self->cgi->invitation_text :
                            '';

    if ( $self->hub->checker->check_permission('admin_workspace') ) {
        for my $user_data ( values %users ) {
            $self->invite_one_user( $user_data, $extra_invite_text );
        }
    }
    else {
        $self->invite_request_to_admin( \%users, $extra_invite_text );
    }

    my $settings_section = $self->template_process(
        'element/settings/users_invited_section',
        users_invited         => [ sort keys %users ],
        users_already_present => [ sort @present ],
        invalid_addresses     => [ sort @{ $invalid } ],
        $self->status_messages_for_template,
    );

    $self->screen_template('view/settings');
    return $self->render_screen(
        settings_table_id => 'settings-table',
        settings_section  => $settings_section,
        hub               => $self->hub,
        display_title     => loc('Users: Invite New Users'),
        pref_list         => $self->_get_pref_list,
    );
}

sub _split_email_addresses {
    my $self = shift;
    return grep /\S/, split(/[,\r\n]+\s*/, $_[0]);
}

sub _parse_email_address {
    my $self = shift;
    my $email = shift;

    return unless defined $email;

    my ($address) = Email::Address->parse($email);
    return unless $address;

    my ( $first, $last );
    if ( grep { defined && length } $address->name ) {
        my $name = $address->name;
        $name =~ s/^\s+|\s+$//g;

        ( $first, $last ) = split /\s+/, $name, 2;
    }

    return lc $address->address, $first, $last;
}

sub invite_request_to_admin {
    my $self = shift;
    my $user_hash   = shift;
    my $extra_text  = shift;
    my $user_string = '';
    my $admin_email = join( ',', $self->get_admins );
    my @invited_users;
    foreach my $user ( values %$user_hash ) {
        push( @invited_users, $user->{email_address} );
    }

    my $renderer = Socialtext::TT2::Renderer->instance();
    my $subject  = loc('Request to invite new users to the [_1] workspace',$self->hub->current_workspace->title);

    my $template_dir = $self->hub->current_workspace->invitation_template;
    my $url = $self->hub->current_workspace->uri . "?action=users_invite";

    my %vars = (
        inviting_user   => $self->hub->current_user->email_address,
        workspace_title => $self->hub->current_workspace->title,
        invited_users   => [@invited_users],
        url             => $url,
        extra_text      => $extra_text,
        appconfig       => Socialtext::AppConfig->instance,
    );

    my $text_body = $renderer->render(
        template => "email/$template_dir/invite-request-email.txt",
        vars     => \%vars,
    );

    my $html_body = $renderer->render(
        template => "email/$template_dir/invite-request-email.html",
        vars     => \%vars,
    );

    my $locale = system_locale();
    my $email_sender = Socialtext::EmailSender::Factory->create($locale);
    $email_sender->send(
        from      => $self->hub->current_user->name_and_email,
        to        => $admin_email,
        subject   => $subject,
        text_body => $text_body,
        html_body => $html_body,
    );

}

sub invite_one_user {
    my $self = shift;
    my $user_data  = shift;
    my $extra_text = shift;

    my $invitation =
    Socialtext::WorkspaceInvitation->new(
        workspace          => $self->hub->current_workspace,
        from_user          => $self->hub->current_user,
        invitee            => $user_data->{email_address},
        invitee_first_name => $user_data->{first_name},
        invitee_last_name  => $user_data->{last_name},
        extra_text         => $extra_text,
        viewer             => $self->hub->viewer
    );
    $invitation->send();
}

package Socialtext::UserSettings::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'Button';
cgi new_password        => '-trim';
cgi new_password_retype => '-trim';
cgi old_password        => '-trim';
cgi 'remove_user';
cgi 'reset_password';
cgi 'should_be_admin';
cgi 'user_search';
cgi 'email_addresses';
cgi 'users_new_ids';
cgi 'first_name';
cgi 'last_name';
cgi 'append_invitation';
cgi 'invitation_text';

1;
