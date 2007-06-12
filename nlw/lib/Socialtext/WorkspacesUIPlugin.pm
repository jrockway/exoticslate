# @COPYRIGHT@
package Socialtext::WorkspacesUIPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use Class::Field qw( const );
use Socialtext::AppConfig;
use Socialtext::Permission qw( ST_EMAIL_IN_PERM );
use Socialtext::Role;
use Template::Iterator::AlzaboWrapperCursor;
use Socialtext::Challenger;

sub class_id { 'workspaces_ui' }
const cgi_class => 'Socialtext::WorkspacesUI::CGI';

sub register {
    my $self = shift;
    my $registry = shift;
    # Web UI
    $registry->add(action => 'workspaces_settings_appearance');
    $registry->add(action => 'workspaces_settings_features');
    $registry->add(action => 'workspaces_listall');
    $registry->add(action => 'workspaces_create');
    $registry->add(action => 'workspaces_created');
    $registry->add(action => 'workspaces_unsubscribe');
    $registry->add(action => 'workspaces_permissions');
    $registry->add( action => 'workspaces_html' );
}

sub workspaces_listall {
    my $self = shift;
    if ( $self->hub()->current_user()->is_guest() ) {
        Socialtext::Challenger->Challenge( type    => 
                                                'settings_requires_account' );
    }

    $self->_update_selected_workspaces()
        if $self->cgi->Button;

    my $settings_section = $self->template_process(
        'element/settings/workspaces_listall_section',
        workspaces_with_selected =>
        Template::Iterator::AlzaboWrapperCursor->new( $self->hub->current_user->workspaces_with_selected ),
        $self->status_messages_for_template,
    );

    $self->screen_template('view/settings');
    return $self->render_screen(
        settings_table_id => 'settings-table',
        settings_section  => $settings_section,
        hub               => $self->hub,
        display_title     => 'Workspaces: My Workspaces',
        pref_list         => $self->_get_pref_list,
    );
}

sub _update_selected_workspaces {
    my $self = shift;
    $self->hub->current_user->set_selected_workspaces(
        workspaces =>
        [ map { Socialtext::Workspace->new( workspace_id => $_ ) } $self->cgi->selected_workspace_id ],
    );

    $self->message("Changes Saved");
}

sub workspaces_settings_appearance {
    my $self = shift;

    return $self->_workspace_settings('appearance');
}

sub workspaces_settings_features {
    my $self = shift;

    return $self->_workspace_settings('features');
}

sub _workspace_settings {
    my $self = shift;
    my $type = shift;

    $self->hub->assert_current_user_is_admin;

    $self->_update_workspace_settings()
        if $self->cgi->Button;

    my $section_template = "element/settings/workspaces_settings_${type}_section";
    my $settings_section = $self->template_process(
        $section_template,
        workspace => $self->hub->current_workspace,
        $self->status_messages_for_template,
    );

    $self->screen_template('view/settings');
    return $self->render_screen(
        settings_table_id => 'settings-table',
        settings_section  => $settings_section,
        hub               => $self->hub,
        display_title     => 'Workspaces: This Workspace',
        pref_list         => $self->_get_pref_list,
    );
}

sub _update_workspace_settings {
    my $self = shift;

    my %update;
    for my $f ( qw( title incoming_email_placement 
                    email_notify_is_enabled sort_weblogs_by_create
                    homepage_is_dashboard ) ) {

        $update{$f} = $self->cgi->$f()
            if $self->cgi->defined($f);
    }

    eval {
        my $icon = $self->cgi->logo_file;

        $self->hub->current_workspace->update(%update);
        if ( $self->cgi->logo_type eq 'uri' and $self->cgi->logo_uri ) {
            $self->hub->current_workspace->set_logo_from_uri(
                uri => $self->cgi->logo_uri,
            );
        }
        elsif ( $icon and $icon->{filename} ) {
            $self->_process_logo_upload( $icon );
        }
    };
    if ( my $e = Exception::Class->caught('Socialtext::Exception::DataValidation') ) {
        $self->add_error($_) for $e->messages;
    }
    elsif ( $@ ) {
        die $@;
    }

    return if $self->input_errors_found;

    $self->message("Changes saved");
}

sub _process_logo_upload {
    my $self = shift;
    my $logo = shift;

    $self->hub->current_workspace->set_logo_from_filehandle(
        filehandle => $logo->{handle},
        filename   => $logo->{filename},
    );
}

sub workspaces_create {
    my $self = shift;
    $self->hub->assert_current_user_is_admin;

    if ( $self->cgi->Button ) {
        my $ws = $self->_create_workspace();
        $self->redirect( 'action=workspaces_created;workspace_id=' . $ws->workspace_id )
            if $ws;
    }

    my $settings_section = $self->template_process(
        'element/settings/workspaces_create_section',
        workspace => $self->hub->current_workspace,
        $self->status_messages_for_template,
    );

    $self->screen_template('view/settings');
    return $self->render_screen(
        settings_table_id => 'settings-table',
        settings_section  => $settings_section,
        hub               => $self->hub,
        display_title     => 'Workspaces: Create New Workspace',
        pref_list         => $self->_get_pref_list,
    );
}

sub _create_workspace {
    my $self = shift;
    my $ws;
    my $account_id = shift || $self->cgi->account_id;
    $account_id ||= $self->hub->current_workspace->account_id;

    eval {
        my $current_ws = $self->hub->current_workspace;
        $ws = Socialtext::Workspace->create(
            name    => $self->cgi->name,
            title   => $self->cgi->title,
            created_by_user_id => $self->hub->current_user->user_id,
            # begin customization inheritances
            skin_name  => $self->hub->current_workspace->skin_name,
            invitation_filter => $self->hub->current_workspace->invitation_filter,
            email_notification_from_address => $self->hub->current_workspace->email_notification_from_address,
            restrict_invitation_to_search =>
                    $self->hub->current_workspace->restrict_invitation_to_search,
            invitation_template =>
                    $self->hub->current_workspace->invitation_template,
            show_welcome_message_below_logo => $current_ws->show_welcome_message_below_logo,
            show_title_below_logo => $current_ws->show_title_below_logo,
            header_logo_link_uri => $current_ws->header_logo_link_uri,
            # end customization inheritances
            account_id => $account_id,
        );

        $ws->set_logo_from_uri( uri => $self->cgi->logo_uri )
            if $self->cgi->logo_uri;

        # XXX - need to give child workspace its parents permissions
    };

    if ( my $e = Exception::Class->caught('Socialtext::Exception::DataValidation') ) {
        $self->add_error($_) for $e->messages;
        return;
    }
    die $@ if $@;

    return $ws;
}

sub workspaces_created {
    my $self = shift;
    my $ws = Socialtext::Workspace->new( workspace_id => $self->cgi->workspace_id );

    my $settings_section = $self->template_process(
        'workspaces_created_section.html',
        workspace => $ws,
        $self->status_messages_for_template,
    );

    $self->screen_template('view/settings');
    return $self->render_screen(
        settings_table_id => 'settings-table',
        settings_section  => $settings_section,
        hub               => $self->hub,
        display_title     => 'Workspaces: Created New Workspace',
        pref_list         => $self->_get_pref_list,
    );
}

sub workspaces_unsubscribe {
    my $self = shift;
    if ( $self->hub()->current_user()->is_guest() ) {
        Socialtext::Challenger->Challenge( type    => 
                                                'settings_requires_account' );

    }

    if ( $self->cgi->Button ) {
        $self->hub->current_workspace->remove_user( user => $self->hub->current_user );
        $self->redirect('');
    }

    my $settings_section = $self->template_process(
        'element/settings/workspaces_unsubscribe_section',
        workspace => $self->hub->current_workspace,
        $self->status_messages_for_template,
    );

    $self->screen_template('view/settings');
    return $self->render_screen(
        settings_table_id => 'settings-table',
        settings_section  => $settings_section,
        hub               => $self->hub,
        display_title     => 'Workspaces: Unsubscribe',
        pref_list         => $self->_get_pref_list,
    );
}

sub workspaces_permissions {
    my $self = shift;

    $self->hub()->assert_current_user_is_admin();

    $self->_set_workspace_permissions()
        if $self->cgi()->Button();

    my $set_name
        = $self->hub->current_workspace->current_permission_set_name();
    my $settings_section = $self->template_process(
        'element/settings/workspaces_permissions_section',
        workspace                   => $self->hub->current_workspace,
        is_appliance                => Socialtext::AppConfig->is_appliance(),
        current_permission_set_name => $set_name,
        fill_in_data                => {
            permission_set_name => $set_name,
            guest_has_email_in  =>
                $self->hub->current_workspace->role_has_permission(
                    role       => Socialtext::Role->Guest(),
                    permission => ST_EMAIL_IN_PERM,
                ),
        },
        $self->status_messages_for_template,
    );

    $self->screen_template('view/settings');

    return $self->render_screen(
        settings_table_id => 'settings-table',
        settings_section  => $settings_section,
        hub               => $self->hub,
        display_title     => 'Workspaces: Permissions',
        pref_list         => $self->_get_pref_list,
    );
}

sub _set_workspace_permissions {
    my $self = shift;

    my $set_name = $self->cgi()->permission_set_name();

    return
        unless $set_name
        and
        Socialtext::Workspace->PermissionSetNameIsValid($set_name);

    my $ws = $self->hub()->current_workspace();
    $ws->set_permissions( set_name => $set_name );

    if ( $self->cgi()->guest_has_email_in() ) {
        $ws->add_permission(
            role       => Socialtext::Role->Guest(),
            permission => ST_EMAIL_IN_PERM,
        );
    }
    else {
        $ws->remove_permission(
            role       => Socialtext::Role->Guest(),
            permission => ST_EMAIL_IN_PERM,
        );
    }

    my $message = 'The permissions for ' . $ws->name() . " have been set to $set_name.";
    if ($self->cgi()->guest_has_email_in()) {
        $message .= ' Anyone can send email to ' . $ws->name() . '.';
    } else {
        if ($ws->current_permission_set_name() =~ /public-(?:read|comment)-only/) {
            $message .= ' Only workspace members';
        } else {
            $message .= ' Only registered users';
        }
       $message .= ' can send email to ' . $ws->name() . '.';
    }

    $self->message( $message );
}

sub workspaces_html {
    my $self = shift;
    return $self->template_process(
        'workspaces_box_filled.html',
        workspaces =>
        Template::Iterator::AlzaboWrapperCursor->new(
            $self->hub->current_user->workspaces( selected_only => 1 ) ),
    ) || ' ';
}


package Socialtext::WorkspacesUI::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'Button';
cgi name => '-clean';
cgi logo_uri => '-clean';
cgi 'logo_type';
cgi logo_file => '-upload';
cgi 'title';
cgi 'selected_workspace_id';
cgi 'incoming_email_placement';
cgi 'email_notify_is_enabled';
cgi 'homepage_is_dashboard';
cgi 'workspace_id';
cgi 'user_email';
cgi 'user_first_name';
cgi 'user_last_name';
cgi 'sort_weblogs_by_create';
cgi 'account_id';
cgi 'account_name';
cgi 'permission_set_name';
cgi 'guest_has_email_in';

1;
