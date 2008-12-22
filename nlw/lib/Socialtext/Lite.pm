# @COPYRIGHT@
package Socialtext::Lite;
use strict;
use warnings;

use Readonly;
use Socialtext::Formatter::LiteLinkDictionary;
use Socialtext::Authen;
use Socialtext::String;
use Socialtext::Permission 'ST_EDIT_PERM';
use Socialtext::Helpers;
use Socialtext::l10n qw(loc);
use Socialtext::Timer;
use Socialtext::Session;

=head1 NAME

Socialtext::Lite - A set of lightweight entry points to the NLW application

=head1 SYNOPSIS

    my $page_display = Socialtext::Lite->new( hub => $nlw->hub )->display($page);

=head1 DESCRIPTION

NLW can present a variety of views into the data in a workspace, but the entry
points to this activity are often obscured behind many layers of code.
Socialtext::Lite provides a way to perform some of these actions in a
straightforward manner. It assumes that a L<Socialtext::Hub> is already
available and fully initialized.

Socialtext::Lite is currently built as a class from which you create an object
on which to call methods. There's, as yet, not much reason for this but
it makes for a familiar calling convention.

See L<Socialtext::Handler::Page::Lite> for a mod perl Handler that implements
a simple interface to NLW using Socialtext::Lite.

Socialtext::Lite is not fully robust in the face of unexpected conditions.

Socialtext::Lite is trying to be a simple way to create or demonsrate alternate
interfaces to the workspaces, users and pages manages by NLW. In the
process it may suggest ways in which the rest of the system can be 
made more simple, or classes could be extracted into their component
parts.

Socialtext::Lite is limited in functionality by design. Before adding something
ask yourself if it is really necessary.

=head1 URIs in HTML output

Socialtext::Lite returns URIs that begin with /lite/. No index.cgi is used, as
with the traditional interface to NLW. L<Socialtext::Formatter> is tightly 
coupled with it's presentation level, traditional NLW, by default
generating URIs specific to that view. Because of this Socialtext::Lite
overrides some methods in the formatter. These overrides are done in
the _frame_page method.

=cut

# The templates we display with
Readonly my $LOGIN_TEMPLATE          => 'lite/login/login.html';
Readonly my $DISPLAY_TEMPLATE        => 'lite/page/display.html';
Readonly my $EDIT_TEMPLATE           => 'lite/page/edit.html';
Readonly my $CONTENTION_TEMPLATE     => 'lite/page/contention.html';
Readonly my $CHANGES_TEMPLATE        => 'lite/changes/changes.html';
Readonly my $SEARCH_TEMPLATE         => 'lite/search/search.html';
Readonly my $CATEGORY_TEMPLATE       => 'lite/category/category.html';
Readonly my $WORKSPACE_LIST_TEMPLATE => 'lite/workspace_list/workspace_list.html';

=head1 METHODS

=head2 new(hub => $hub)

Creates a new Socialtext::Lite object. If no hub is passed, the Socialtext::Lite
object will be unable to perform.

=cut
sub new {
    my $class = shift;
    my %p     = @_;

    $class = ref($class) || $class;

    my $self = bless {}, $class;

    $self->{hub} = $p{hub};

    return $self;
}

=head2 hub

Returns the hub that will be used to find classes and data. Currently
only an accessor.

=cut
sub hub {
    my $self = shift;
    return $self->{hub};
}

=head2 login()

Shows a mobile version of the login page.

=cut
sub login {
    my $self        = shift;
    my $redirect_to = shift || '/lite/workspace_list';
    my $session     = Socialtext::Session->new();
    return $self->_process_template(
        $LOGIN_TEMPLATE,
        redirect_to       => $redirect_to,
        errors            => [ $session->errors ],
        messages          => [ $session->messages ],
        username_label    => Socialtext::Authen->username_label,
        public_workspaces =>
            [ $self->hub->workspace_list->public_workspaces ],
    );
}

=head2 display($page)

Given $page, a L<Socialtext::Page>, returns a string of HTML suitable for
output to a web browser.

=cut
sub display {
    my $self = shift;
    my $page = shift || $self->hub->pages->current;
    return $self->_frame_page($page);
}

=head2 edit_action($page)

Presents HTML including a form for editing $page, a L<Socialtext::Page>.

=cut
sub edit_action {
    my $self = shift;
    my $page = shift;
    # XXX would rather not send the page object, but can't decide
    return $self->_process_template(
        $EDIT_TEMPLATE,
        workspace_name => $self->hub->current_workspace->name,
        page => $page,
        page_body => $page->content,
        page_title => $page->title,
    );
}

=head2 edit_save($page)

Expects CGI data provided from the form in C<edit_action>. Updates
$page with content and other data provided by the CGI data.

If no revision_id, revision or subject are provided in the CGI
data, use the information in the provided page object.

=cut 
sub edit_save {
    my $self = shift;
    my %p    = @_;

    my $page = $p{page};
    delete $p{page};

    eval { $page->update_from_remote(%p); };
    if ( $@ =~ /^Contention:/ ) {
        return $self->_handle_contention( $page, $p{subject}, $p{content} );
    }
    elsif ($@) {
        # rethrow
        die $@;
    }

    return '';    # insure that we are returning no content
}

=head2 recent_changes

Returns HTML representing the list of the fifty (or less) most 
recently changed pages in the current workspace.

=cut 

sub recent_changes {
    my $self     = shift;
    my $category = shift || '';
    my $changes = $self->hub->recent_changes->get_recent_changes_in_category(
        count    => 50,
        category => $category,
    );

    my $title = 'Recent Changes';
    $title .= " in $category" if $category;

    return $self->_process_template(
        $CHANGES_TEMPLATE,
        workspace_name => $self->hub->current_workspace->name,
        title          => $title,
        category       => $category,
        %$changes,
    );
}

=head2 workspace_list()

Returns a list of the workspaces that the user has access to, including any
public workspaces.

=cut

sub workspace_list {
    my $self  = shift;
    my $title = 'Workspace List';
    return $self->_process_template(
        $WORKSPACE_LIST_TEMPLATE,
        workspace_title   => $title,
        login_logout      => $self->_login_logout,
        my_workspaces     => [ $self->hub->workspace_list->my_workspaces ],
        public_workspaces => [ $self->hub->workspace_list->public_workspaces ],
    );
}

=head2 search([$search_term])

Returns a form for searching the current workspace. If $search_term 
is defined, the results of that search are provided as a list of links
to pages.

=cut 
sub search {
    my $self = shift;
    my $search_term = $self->_utf8_decode(shift);
    my $search_results;
    my $title = 'Search';
    my $error = '';

    if ( $search_term ) {
        eval {
            $search_results = $self->hub->search->get_result_set(search_term => $search_term);
        };
        if ($@) {
            $error = $@;
            $title = 'Search Error';
        }
        else {
            $title = $search_results->{display_title};
        }
    }

    return $self->_process_template(
        $SEARCH_TEMPLATE,
        search_term    => $search_term,
        workspace_name => $self->hub->current_workspace->name,
        title          => $title,
        search_error   => $error,
        %$search_results,
    );
}

=head2 category([$category])

If $category is not defined, provide a list of links to all categories
in the current workspace. If $category is defined, provide a list of
links to all the pages in the category.

=cut 
sub category {
    my $self = shift;
    my $category = $self->_utf8_decode(shift);

    if ($category) {
        return $self->_pages_for_category($category);
    }
    else {
        return $self->_all_categories();
    }
}

sub _pages_for_category {
    my $self = shift;
    my $category = shift;

    my $rows = $self->hub->category->get_page_info_for_category($category);
    return $self->_process_template(
        $CATEGORY_TEMPLATE,
        workspace_name => $self->hub->current_workspace->name,
        title          => loc("Category [_1]", $category),
        rows           => $rows,
        category       => $category,
    );
}

sub _all_categories {
    my $self = shift;

    return $self->_process_template(
        $CATEGORY_TEMPLATE,
        title          => loc('Categories'),
        categories     => [ $self->hub->category->all ],
        workspace_name => $self->hub->current_workspace->name,
    );
}


# XXX utf8_decode should be on Socialtext::String not Socialtext::Base
sub _utf8_decode {
    my $self = shift;
    my $text = shift;
    return $self->hub->utf8_decode($text);
}

sub _handle_contention {
    my $self    = shift;
    my $page    = shift;
    my $subject = shift;
    my $content = shift;

    return $self->_process_template(
        $CONTENTION_TEMPLATE,
        title          => "$subject Editing Error",
        content        => $content,
        page_uri       => $page->uri,
        workspace_name => $self->hub->current_workspace->name,
        edit_link      => $self->_edit_link($page),
    );
}

sub _frame_page {
    my $self = shift;
    my $page = shift;

    my $attachments = $self->_get_attachments($page);

    my $edit_link = $self->_edit_link($page);

    $self->hub->viewer->link_dictionary(
        Socialtext::Formatter::LiteLinkDictionary->new() );
    
    Socialtext::Timer->Continue('lite_page_html');
    my $html = $page->to_html_or_default;
    Socialtext::Timer->Pause('lite_page_html');

    return $self->_process_template(
        $DISPLAY_TEMPLATE,
        page_html        => $html,
        title            => $page->title,
        edit_link        => $edit_link,
        login_logout     => $self->_login_logout($page->uri),
        page_update_info => $self->_page_update_info($page),
        attachments      => $attachments,
        # XXX next two for attachments, because we are using legacy urls
        # for now
        page_uri         => $page->uri,
        workspace_name   => $self->hub->current_workspace->name,
    );
}

sub _login_logout {
    my $self = shift;
    my $page_uri = shift;
    if ($self->hub->current_user->is_guest) {
        my $uri = $self->hub->current_workspace->uri;
        $uri =~ s#^(.*://[^/]+)/([^/]+)#$1/lite/page/$2/$page_uri#g;
        return '<a href="/challenge?' . $uri . '">' . loc('Log in') . '</a>';
    } else {
        return '<a href="/nlw/submit/logout?redirect_to=/lite/login">' . loc('Log out') . '</a>';
    }
}

sub _process_template {
    my $self     = shift;
    my $template = shift;
    my %vars     = @_;

    my %ws_vars;
    if ($self->hub->current_workspace->real) {
        %ws_vars = (
            home_link       => $self->_home_link,
            rc_link         => $self->_recent_changes_link,
            search_link     => $self->_search_link,
            workspace_title => $self->hub->current_workspace->title,
        );
    }

    return $self->hub->template->process(
        $template,
        brand_stamp     => $self->hub->main->version_tag,
        static_path     => Socialtext::Helpers::static_path,
        skin_uri        => sub { $self->hub->skin->skin_uri($_[0]) },
        user            => $self->hub->current_user,
        %ws_vars,
        %vars,
    );
}

sub _get_attachments {
    my $self = shift;
    my $page = shift;

    my @attachments = sort { lc( $a->filename ) cmp lc( $b->filename ) }
        @{ $self->hub->attachments->all( page_id => $page->id ) };

    return \@attachments;
}


sub _page_update_info {
    my $self = shift;
    my $page = shift;

    return '' unless $page->active;

    my $page_date   = $page->datetime_for_user,
    my $page_author = $page->last_edited_by->best_full_name;
    return "$page_date by $page_author";
}

sub _edit_link {
    my $self           = shift;
    my $page = shift;
    my $authz = Socialtext::Authz->new;
    unless ( $authz->user_has_permission_for_workspace(
                 user       => $self->hub->current_user,
                 permission => ST_EDIT_PERM,
                 workspace  => $self->hub->current_workspace,
             ) ) {
        return $self->_login_logout($page->uri);
    }

    my $workspace_name = $self->hub->current_workspace->name;
    my $edit = loc('Edit');
    return qq{<a href="/lite/page/$workspace_name/}
        . $page->uri
        . qq{?action=edit">$edit</a>};
}

sub _home_link {
    my $self           = shift;
    my $workspace_name = $self->hub->current_workspace->name;
    my $home = loc("Home");
    return qq{<a href="/lite/page/$workspace_name/">$home</a>};
}

sub _recent_changes_link {
    my $self           = shift;
    my $workspace_name = $self->hub->current_workspace->name;
    my $rc = loc('Recent Changes');
    return qq{<a href="/lite/changes/$workspace_name">$rc</a>};
}

sub _search_link {
    my $self           = shift;
    my $workspace_name = $self->hub->current_workspace->name;
    my $search = loc('Search');
    return qq{<a href="/lite/search/$workspace_name">$search</a>};
}

1;

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

