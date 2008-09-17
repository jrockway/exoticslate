# @COPYRIGHT@
package Socialtext::WorkspacesUIPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use File::Spec;
use Class::Field qw( const );
use Socialtext::AppConfig;
use Socialtext::Permission qw( ST_EMAIL_IN_PERM );
use Socialtext::Role;
use Socialtext::Challenger;
use Socialtext::l10n qw(loc);
use Socialtext::File::Copy::Recursive qw(dircopy);
use YAML qw(LoadFile);

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
            $self->hub->current_user->workspaces_with_selected,
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
    my %args = @_;

    my $skin_path = $self->custom_skin_path();

    my @skin_files = ();

    if (-e $skin_path) {
        push @skin_files, map {
            {
                name => (split m{$skin_path/(.*)})[1] || "",
                size => -s $_,
                date => $self->hub->timezone->date_local_epoch((stat($_))[9])
            }
        } Socialtext::File::files_under($skin_path);
    }

    $self->_reconfigure_workspace_for_skin($args{info_yaml});

    my $a = $self->_render_page(
        "element/settings/workspaces_settings_skin_section",
        skin_files => \@skin_files,
        uploaded_skin => $self->hub->current_workspace->uploaded_skin,
        %args,
    );
    open my $fh, ">/tmp/a"; print $fh $a; return $a;
}

sub _reconfigure_workspace_for_skin {
    my $self = shift;
    my $config = shift; # [in] workspace config in info.yaml

    if (exists($config->{cascade_css})) {
        $self->hub->current_workspace->update(
            cascade_css => ($config->{cascade_css} ? 1 : 0),
        );
    }
    $self->hub->current_workspace->customjs_uri($config->{customjs_name} || "");
}

sub workspaces_settings_skin {
    my $self = shift;

    $self->hub->assert_current_user_is_admin;

    my $error_message = '';
    my @skipped_files = ();

    if ($self->cgi->Button) {
        my $uploaded = $self->cgi->uploaded_skin;
        if ($uploaded ne $self->hub->current_workspace->uploaded_skin) {
            $self->hub->current_workspace->update(uploaded_skin => $uploaded)
        }
    }

    return $self->_render_skin_settings_page(
        settings_error => $error_message
    );
}

sub skin_upload {
    my $self = shift;

    $self->hub->assert_current_user_is_admin;

    my $error_message = '';
    my @skipped_files = ();
    my $info_yaml;
    $self->_extract_skin(\$error_message, \@skipped_files, \$info_yaml);

    return $self->_render_skin_settings_page(
        settings_error => $error_message,
        info_yaml => $info_yaml,
        skipped_files => \@skipped_files,
    );
}

sub remove_skin_files {
    my $self = shift;

    $self->hub->assert_current_user_is_admin;

    my $skin_path = $self->custom_skin_path();
    Socialtext::File::clean_directory($skin_path);

    $self->hub->current_workspace->update(
        uploaded_skin => 0,
    );

    return $self->_render_skin_settings_page;
}

sub custom_skin_path {
    my $self = shift;
    return $self->hub->skin->skin_upload_path(
        $self->hub->current_workspace->name
    );
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
    if ($@ or not @$files) {
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

    my $skin_path = $self->custom_skin_path();

    my ($basedir) = map { m{^(.*/)css/screen\.css$} } @$files;
    unless ($basedir) {
        $$error = loc("The uploaded skin does not contain css/screen.css");
        return;
    }

    my $files_to_copy = qr{ ^(?: css/        |
                                 template/   |
                                 images/     |
                                 javascript/ |
                                 info\.yaml$
                        )}xsm;

    foreach (@$files) {
        my $basefile = $_;
        $basefile =~ s/^$basedir//;
        my ($filename, $path) = File::Basename::fileparse($basefile);

        next if $filename =~ /^\./; # ignore hidden files

        if ($basefile =~ $files_to_copy) {
            Socialtext::File::ensure_directory("$skin_path/$path");
            File::Copy::copy($_, "$skin_path/$basefile")
        }
        elsif ($basefile !~ m{^(?:samples/|README)}) {
            warn "Not including $path";
            push @$skipped_files, $basefile;
        }
    }

    return 1;
}

sub _extract_skin {
    my $self = shift;
    my $error_message = shift; # [out] String to hold any error message
    my $skipped_files = shift; # [out] Array of files skipped during extract
    my $info_yaml = shift; # [out] info.yaml parsed information

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

    # Copy skin files to the custom folder(s)
    if (0 < @archive_files) {
        $self->_install_skin_files(\@archive_files, $error_message, $skipped_files)
    }

    $self->_parse_info_yaml(\@archive_files, $error_message, $info_yaml);

    return $ok;
}

sub _parse_info_yaml {
    my $self = shift;
    my $archive_files = shift; # [in] Files in the archive.
    my $error_message = shift; # [out] list of errors.
    my $info_yaml = shift; # [out] info.yaml parsed information.

    for my $file (@$archive_files) {
        eval {
            $$info_yaml = LoadFile($file) # YAML
              if -e $file && $file =~ m{/info.yaml$};
        };
        if ($@) {
            $$error_message = "Error parsing info.yaml file"
        }
    }
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

    if ($self->cgi->defined('homepage_is_weblog')) {
        if ($self->cgi->homepage_is_weblog and not $self->cgi->homepage_weblog) {
            $self->add_error(loc('You selected a homepage as weblog, but did not select a weblog name.  Your changes were not saved'))
        }
        $update{homepage_weblog} = $self->cgi->homepage_is_weblog ?
            $self->cgi->homepage_weblog : '';
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

    $self->hub->current_workspace->set_logo_from_file(
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
            #
            # begin customization inheritances
            #
            cascade_css => $self->hub->skin->cascade_css,
            customjs_name => $self->hub->skin->customjs_name,
            skin_name  => $self->hub->skin->skin_name,
            #
            customjs_uri => $current_ws->customjs_uri,
            uploaded_skin => $current_ws->uploaded_skin,
            no_max_image_size => $current_ws->no_max_image_size,
            invitation_filter => $current_ws->invitation_filter,
            email_notification_from_address => $current_ws->email_notification_from_address,
            restrict_invitation_to_search => $current_ws->restrict_invitation_to_search,
            invitation_template => $current_ws->invitation_template,
            show_welcome_message_below_logo => $current_ws->show_welcome_message_below_logo,
            show_title_below_logo => $current_ws->show_title_below_logo,
            header_logo_link_uri => $current_ws->header_logo_link_uri,
            #
            # end customization inheritances
            #
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
        = $self->hub->current_workspace->permissions->current_set_name();
    my $settings_section = $self->template_process(
        'element/settings/workspaces_permissions_section',
        workspace                   => $self->hub->current_workspace,
        is_appliance                => Socialtext::AppConfig->is_appliance(),
        current_permission_set_name => $set_name,
        fill_in_data                => {
            permission_set_name => $set_name,
            guest_has_email_in  =>
                $self->hub->current_workspace->permissions->role_can(
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
        exists $Socialtext::Workspace::Permissions::PermissionSets{ $set_name };

    my $ws = $self->hub()->current_workspace();
    $ws->permissions->set( set_name => $set_name );

    if ( $self->cgi()->guest_has_email_in() ) {
        $ws->permissions->add(
            role       => Socialtext::Role->Guest(),
            permission => ST_EMAIL_IN_PERM,
        );
    }
    else {
        $ws->permissions->remove(
            role       => Socialtext::Role->Guest(),
            permission => ST_EMAIL_IN_PERM,
        );
    }

    my $message = loc('The permissions for [_1] have been set to [_2].', $ws->name(), loc($set_name));
    if ($self->cgi()->guest_has_email_in()) {
        $message .= ' ' . loc('Anyone can send email to [_1].', $ws->name());
    } else {
        if ($ws->permissions->current_set_name() =~ /public-(?:read|comment)-only/) {
            $message .= ' ';
            $message .= loc('Only workspace members can send email to [_1].', $ws->name());
        } else {
            $message .= ' ';
            $message .= loc('Only registered users can send email to [_1].', $ws->name());
        }
    }

    $self->message( $message );
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
cgi 'homepage_is_weblog';
cgi 'homepage_weblog';
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
cgi 'uploaded_skin';
cgi 'skin_reset';
cgi skin_file => '-upload';

1;
