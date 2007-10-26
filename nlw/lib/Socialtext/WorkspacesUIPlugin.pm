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
use Socialtext::l10n qw(loc);
use Socialtext::CSS;
use Socialtext::File::Copy::Recursive qw(dircopy);

sub class_id { 'workspaces_ui' }
const cgi_class => 'Socialtext::WorkspacesUI::CGI';

sub register {
    my $self = shift;
    my $registry = shift;
    # Web UI
    $registry->add(action => 'workspaces_settings_appearance');
    $registry->add(action => 'workspaces_settings_skin');
    $registry->add(action => 'skin_upload');
    $registry->add(action => 'remove_skin_files');
    $registry->add(action => 'workspaces_settings_features');
    $registry->add(action => 'workspaces_listall');
    $registry->add(action => 'workspaces_create');
    $registry->add(action => 'workspaces_created');
    $registry->add(action => 'workspaces_unsubscribe');
    $registry->add(action => 'workspaces_permissions');
    $registry->add(action => 'workspaces_html');
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
        display_title     => loc('Workspaces: My Workspaces'),
        pref_list         => $self->_get_pref_list,
    );
}

sub _update_selected_workspaces {
    my $self = shift;
    $self->hub->current_user->set_selected_workspaces(
        workspaces =>
        [ map { Socialtext::Workspace->new( workspace_id => $_ ) } $self->cgi->selected_workspace_id ],
    );

    $self->message(loc("Changes Saved"));
}

sub workspaces_settings_appearance {
    my $self = shift;

    return $self->_workspace_settings('appearance');
}

sub _render_page {
    my $self = shift;
    my $section_template = shift;
    my %p = @_;

    my $settings_section = $self->template_process(
        $section_template,
        $self->hub->helpers->global_template_vars,
        workspace => $self->hub->current_workspace,
        $self->status_messages_for_template,
        %p,
    );

    $self->screen_template('view/settings');
    return $self->render_screen(
        settings_table_id => 'settings-table',
        settings_section  => $settings_section,
        hub               => $self->hub,
        display_title     => loc('Workspaces: This Workspace'),
        pref_list         => $self->_get_pref_list,
    );
}

sub _render_skin_settings_page {
    my $self = shift;
    my $settings_error = shift; # [in] page level error message
    my $upload_error_message = shift; # [in] Error message for problems when uploading skin
    my $reset_error_message = shift; # [in] Error message for problems when reseting the skin files
    my $skipped_files = shift; # [in/reference] array of extracted skin files not saved
    my $force_radio = shift;

    my ($css_directory, $image_directory) = $self->custom_skin_paths();
    my $custom_skin = $self->custom_skin_name;

    my @skin_files = ();
    if (-e $css_directory) {
        my $sep = "/css/$custom_skin/";
        push @skin_files, map {
            {
                name => (split /$sep/)[1],
                size => -s $_,
                date => $self->hub->timezone->date_local_epoch((stat($_))[9])
            }
        } Socialtext::File::files_under($css_directory);
    }

    if (-e $image_directory) {
        my $sep = "/images/$custom_skin/";
        push @skin_files, map {
            {
                name => (split /$sep/)[1],
                size => -s $_,
                date => $self->hub->timezone->date_local_epoch((stat($_))[9])
            }
        } Socialtext::File::files_under($image_directory);
    }

    return $self->_render_page(
        "element/settings/workspaces_settings_skin_section",
        skin_files => \@skin_files,
        upload_error => $upload_error_message,
        reset_error => $reset_error_message,
        skipped_files => $skipped_files,
        settings_error => $settings_error,
        force_radio => $force_radio,
    );
}

sub workspaces_settings_skin {
    my $self = shift;

    $self->hub->assert_current_user_is_admin;

    my $error_message = '';
    my @skipped_files = ();

    if ($self->cgi->Button) {
        my $new_skin = $self->cgi->skin_name;
        if ($new_skin ne $self->hub->current_workspace->skin_name) {
            $self->_initialize_css_directory($new_skin);
            $self->_initialize_image_directory($new_skin);
            $self->hub->current_workspace->update(skin_name => $new_skin)
        }
    }

    return $self->_render_skin_settings_page($error_message, '', '', []);
}

sub skin_upload {
    my $self = shift;

    $self->hub->assert_current_user_is_admin;

    my $error_message = '';
    my @skipped_files = ();
    $self->_extract_skin(\$error_message, \@skipped_files);

    return $self->_render_skin_settings_page(
        '',
        $error_message,
        '',
        \@skipped_files,
        ($error_message) ? '' : $self->custom_skin_name,
    );
}

sub remove_skin_files {
    my $self = shift;

    $self->hub->assert_current_user_is_admin;

    my ($css_directory, $image_directory) = $self->custom_skin_paths();
    Socialtext::File::clean_directory($css_directory);
    Socialtext::File::clean_directory($image_directory);

    return $self->_render_skin_settings_page('', '', '', [], $self->hub->css->BaseSkin());
}

sub _initialize_css_directory {
    my $self = shift;
    my $skin_name = shift;

    Socialtext::File::ensure_directory($self->hub->css->RootDir . "/$skin_name");
}

sub _initialize_image_directory {
    my $self = shift;
    my $skin_name = shift;

    my $image_path = Socialtext::AppConfig->code_base() . "/images/$skin_name";

    Socialtext::File::ensure_directory($image_path);
}

sub custom_skin_paths {
    my $self = shift;

    my $custom_skin = $self->hub->current_workspace->name;
    my $image_directory = Socialtext::AppConfig->code_base() . "/images/$custom_skin";
    my $css_directory = $self->hub->css->RootDir . "/$custom_skin";
    return ($css_directory, $image_directory);
}

sub _unpack_skin_file {
    my $self = shift;
    my $file = shift;   # [in] CGI File
    my $tmpdir = shift; # [in] Temp directory to hold the archive's files
    my $error = shift;  # [out] Error message, if any
    my $files = shift;  # [out] Array of files extracted from the archive

    return if (!$file);

    eval {
        my $filename = File::Basename::basename( $file->{filename} );

        if (!Socialtext::ArchiveExtractor::valid_archivename($filename)) {
            $$error = loc('[_1] is not a valid archive filename. Skin files must end with .zip, .tar.gz or .tgz.', $filename );
            return 0;
        }
        my $tmparchive = "$tmpdir/$filename";

        open my $tmpfh, '>', $tmparchive
            or die loc('Could not open [_1]', $file->{filename});
        File::Copy::copy($file->{handle}, $tmpfh)
            or die loc('Cannot extract files from [_1]', $file->{filename});
        close $tmpfh;

        push @$files, Socialtext::ArchiveExtractor->extract( archive => $tmparchive );
    };
    if ($@) {
        $$error = loc('Could not extract files from the skin archive. This is most likely caused by a corrupt archive file. Please check your file and try the upload again.');
        return 0;
    }

    return 1;
}

sub _install_skin_files {
    my $self = shift;
    my $files = shift;         # [in] Array of files to copy to the skin directory
    my $error = shift;         # [out] Error message, if any
    my $skipped_files = shift; # [out] Array of files skipped during the extraction

    return if (0 == @$files);

    my ($css_dir, $image_dir) = $self->custom_skin_paths();

    foreach (@$files) {
        my $basefile = $_;
        $basefile =~ s/^\/.+?\/.+?\///;
        my ($filename, $path, $ext) = File::Basename::fileparse($basefile);

        if ($path =~ /^css/i) {
            $path =~ s/^css\///i;
            $basefile =~ s/^css\///i;
            Socialtext::File::ensure_directory("$css_dir/$path");
            if ($basefile =~ /\.[css|htc]/i) {
                File::Copy::copy($_, "$css_dir/$basefile")
            }
            else {
                push @$skipped_files, $basefile;
            }
        }
        elsif ($path =~ /^images/i) {
            $path =~ s/^images\///i;
            $basefile =~ s/^images\///i;
            Socialtext::File::ensure_directory("$image_dir/$path");
            File::Copy::copy($_, "$image_dir/$basefile")
        }
        else {
            push @$skipped_files, $basefile;
        }
    }

    return 1;
}

sub custom_skin_name {
    my $self = shift;

    return $self->hub->current_workspace->name;
}

sub _extract_skin {
    my $self = shift;
    my $error_message = shift; # [out] String to hold any error message
    my $skipped_files = shift; # [out] Array of files skipped during extract

    my $custom_skin = $self->custom_skin_name;
    my $file = $self->cgi->skin_file;

    if (!$file) {
        $$error_message = loc('A custom skin file was not uploaded.');
        return 0;
    }

    # if we got a file, unpack it
    my $ok = 1;
    my $tmpdir = File::Temp::tempdir( CLEANUP => 1 );
    my @archive_files = ();
    if ($file) {
        $ok = $self->_unpack_skin_file($file, $tmpdir, $error_message, \@archive_files);
        return if (!$ok);
    }

    $self->_initialize_css_directory($custom_skin);
    $self->_initialize_image_directory($custom_skin);

    # Copy skin files to the custom folder(s)
    if (0 < @archive_files) {
        $self->_install_skin_files(\@archive_files, $error_message, $skipped_files)
    }

    return $ok;
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
        $self->hub->helpers->global_template_vars,
        workspace => $self->hub->current_workspace,
        $self->status_messages_for_template,
    );

    $self->screen_template('view/settings');
    return $self->render_screen(
        settings_table_id => 'settings-table',
        settings_section  => $settings_section,
        hub               => $self->hub,
        display_title     => loc('Workspaces: This Workspace'),
        pref_list         => $self->_get_pref_list,
    );
}

sub _update_workspace_settings {
    my $self = shift;

    my %update;
    for my $f ( qw( title incoming_email_placement enable_unplugged
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

    $self->message(loc("Changes saved"));
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
        display_title     => loc('Workspaces: Create New Workspace'),
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
            enable_unplugged => 1,
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
        display_title     => loc('Workspaces: Created New Workspace'),
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
        display_title     => loc('Workspaces: Unsubscribe'),
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
        display_title     => loc('Workspaces: Permissions'),
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

    my $message = loc('The permissions for [_1] have been set to [_2].', $ws->name(), loc($set_name));
    if ($self->cgi()->guest_has_email_in()) {
        $message .= ' ' . loc('Anyone can send email to [_1].', $ws->name());
    } else {
        if ($ws->current_permission_set_name() =~ /public-(?:read|comment)-only/) {
            $message .= ' ';
            $message .= loc('Only workspace members can send email to [_1].', $ws->name());
        } else {
            $message .= ' ';
            $message .= loc('Only registered users can send email to [_1].', $ws->name());
        }
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
cgi 'enable_unplugged';
cgi 'skin_name';
cgi 'skin_reset';
cgi skin_file => '-upload';

1;
