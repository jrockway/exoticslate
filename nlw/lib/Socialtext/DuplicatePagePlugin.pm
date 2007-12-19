# @COPYRIGHT@
package Socialtext::DuplicatePagePlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use Class::Field qw( const );
use Socialtext::AppConfig;
use Socialtext::Page;
use Socialtext::Pages;
use Socialtext::Permission 'ST_EDIT_PERM';

# XXX funkity duplication throughout, trying to remove some
# but still plenty left

sub class_id { 'duplicate_page' }
const cgi_class => 'Socialtext::DuplicatePage::CGI';

sub register {
    my $self = shift;
    $self->hub->registry->add(action => 'duplicate_popup');
    $self->hub->registry->add(action => 'duplicate_page');
    $self->hub->registry->add(action => 'copy_to_workspace');
    $self->hub->registry->add(action => 'copy_to_workspace_popup');
}

sub duplicate_popup {
    my $self = shift;
    my %p = @_;
    $self->template_process(
        'popup/duplicate',
        %p,
        $self->hub->helpers->global_template_vars,
    );
}

sub copy_to_workspace_popup {
    my $self = shift;
    my %p = @_;
    my $current_workspace = $self->hub->current_workspace;
    my $workspaces = $self->hub->current_user->workspaces(
        selected_only => 1,
        exclude       => [ $self->hub->current_workspace->workspace_id ],
    );

    $self->template_process(
        'popup/copy_to_workspace',
        workspaces => Template::Iterator::AlzaboWrapperCursor->new($workspaces),
        %p,
        $self->hub->helpers->global_template_vars,
    );
}

sub duplicate_page {
    my $self = shift;
    my $new_title = $self->cgi->new_title;

    if ( $self->_page_title_bad($new_title) ) {
        return $self->duplicate_popup(
            page_title_bad => 1,
        );
    }
    elsif ( Socialtext::Page->_MAX_PAGE_ID_LENGTH
            < length Socialtext::Page->name_to_id($new_title) ) {
        return $self->duplicate_popup(
            page_title_too_long => 1,
        );
    }
    elsif ( $self->_duplicate( $self->hub->current_workspace ) ) {
        return $self->template_process('close_window.html',
            before_window_close => q{window.opener.location='} .
                Socialtext::AppConfig->script_name . '?' .
                Socialtext::Page->name_to_id($new_title) .
                q{';},
        );
    }

    return $self->duplicate_popup(
        page_exists => 1,
    );
}

sub copy_to_workspace {
    my $self = shift;
    unless ( $self->cgi->target_workspace_id ) {
        return $self->template_process('close_window.html');
    }

    my $target_ws = Socialtext::Workspace->new( workspace_id => $self->cgi->target_workspace_id );
    if ( $self->_page_title_bad( $self->cgi->new_title )) {
        return $self->copy_to_workspace_popup(
            page_title_bad => 1,
        );
    }
    elsif ( Socialtext::Page->_MAX_PAGE_ID_LENGTH
            < length Socialtext::Page->name_to_id( $self->cgi->new_title ) ) {
        return $self->copy_to_workspace_popup(
            page_title_too_long => 1,
        );
    }
    elsif ( $self->_duplicate($target_ws) ) {
        return $self->template_process('close_window.html');
    }

    return $self->copy_to_workspace_popup(
        page_exists => 1,
        target_workspace => $target_ws,
    );
}

sub mass_copy_to {
    my $self = shift;
    my $destination_name = shift;
    my $prefix = shift;
    my $user = shift;

    my $dest_ws = Socialtext::Workspace->new( name => $destination_name );
    my $dest_main = Socialtext->new;
    $dest_main->load_hub(
        current_workspace => $dest_ws,
        current_user      => $self->hub->current_user,
    );
    my $dest_hub = $dest_main->hub;
    $dest_hub->registry->load;

    my $log_title = 'Mass Copy';
    my $log_page = $dest_hub->pages->new_from_name($log_title);
    my $log = $log_page->content;
    for my $page ($self->hub->pages->all) {
        $page->doctor_links_with_prefix($prefix);
        my $old_id = $page->id;
        my $old_name = $page->metadata->Subject;
        my $new_name =
          $old_name =~ /^\Q$prefix\E/ ? $old_name : $prefix . $old_name;
        $page->duplicate(
            $dest_ws,
            $new_name,
            1, # keep categories
            1, # keep attachments
            0, # clobber (hopefully this won't happen if prefixes are used)
        );
        $log .= qq{* "$old_name"<http:/admin/index.cgi?;page_name=$old_id;action=revision_list> became [$new_name]\n};
    }
    $log .= "----\n";
    $log_page->metadata->Subject($log_title);
    $log_page->content($log);
    $log_page->store( user => $user );
}

sub _duplicate {
    my $self = shift;
    my $workspace = shift;

    return 1
        unless $self->hub->authz->user_has_permission_for_workspace(
                   user       => $self->hub->current_user,
                   permission => ST_EDIT_PERM,
                   workspace  => $workspace,
               );


    my $page_exists = $self->hub->pages->page_exists_in_workspace($self->cgi->new_title, $workspace->name);

    return 0 if ($page_exists && $self->cgi->clobber ne $self->cgi->new_title);

    return $self->hub->pages->current->duplicate(
        $workspace,
        $self->cgi->new_title,
        $self->cgi->keep_categories || '',
        $self->cgi->keep_attachments || '',
        $self->cgi->clobber,
    );
}

sub _page_title_bad {
    my ( $self, $title ) = @_;
    return Socialtext::Page->is_bad_page_title($title);
}

package Socialtext::DuplicatePage::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'keep_attachments';
cgi 'keep_categories';
cgi 'new_title';
cgi 'target_workspace_id';
cgi 'clobber';

1;
