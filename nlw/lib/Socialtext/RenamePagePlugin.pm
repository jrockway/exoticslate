# @COPYRIGHT@
package Socialtext::RenamePagePlugin;
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

sub class_id { 'rename_page' }
const cgi_class => 'Socialtext::RenamePage::CGI';

sub register {
    my $self = shift;
    $self->hub->registry->add(action => 'rename_popup');
    $self->hub->registry->add(action => 'rename_page');
}

sub rename_popup {
    my $self = shift;
    my %p = @_;
    $self->template_process(
        'popup/rename',
        %p,
    );
}

sub rename_page {
    my $self = shift;

    my $new_title = $self->cgi->new_title;

    if ( $self->_page_title_bad($new_title)) {
        return $self->rename_popup(
            page_title_bad => 1,
        );
    }
    elsif ( Socialtext::Page->_MAX_PAGE_ID_LENGTH
            < length Socialtext::Page->name_to_id($new_title) ) {
        return $self->rename_popup(
            page_title_too_long => 1,
        );
    }
    elsif ( $new_title eq $self->hub->pages->current->title ) {
        return $self->rename_popup( same_title => 1 );
    }
    elsif ( $self->_rename() ) {
        return $self->template_process('close_window.html',
            before_window_close => q{window.opener.location='} .
                Socialtext::AppConfig->script_name . '?' .
                Socialtext::Page->name_to_id($self->cgi->new_title) .
                q{';},
        );
    }

    return $self->rename_popup(
        page_exists => 1,
    );
}

sub _rename {
    my $self = shift;

    return 1
        unless $self->hub->authz->user_has_permission_for_workspace(
                   user       => $self->hub->current_user,
                   permission => ST_EDIT_PERM,
                   workspace  => $self->hub->current_workspace,
               );

    return $self->hub->pages->current->rename(
        $self->cgi->new_title,
        $self->cgi->keep_categories || '',
        $self->cgi->keep_attachments || '',
        $self->cgi->clobber,
    );
}

# trap titles which are not considered okay
# for now that's just empty ones
sub _page_title_bad {
    my $self = shift;
    my $title = shift;

    return ($title =~ /^\s*$/);
}

package Socialtext::RenamePage::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'keep_attachments';
cgi 'keep_categories';
cgi 'new_title';
cgi 'clobber';

1;

