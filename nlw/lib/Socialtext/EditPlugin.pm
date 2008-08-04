# @COPYRIGHT@
package Socialtext::EditPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use CGI;
use Class::Field qw( const );
use Socialtext::Pages;
use Socialtext::Exceptions qw( data_validation_error );
use Socialtext::l10n qw(loc);
use Socialtext::Events;

sub class_id { 'edit' }
const class_title => 'Editing Page';
const cgi_class => 'Socialtext::Edit::CGI';

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(action => 'edit');
    $registry->add(action => 'edit_save');
    $registry->add(action => 'edit_content');
}

sub edit_save {
    my $self = shift;
    $self->save;
}

sub _validate_pagename_length {
    my $self = shift;
    my $page_name = shift;

    if ( Socialtext::Page->_MAX_PAGE_ID_LENGTH
         < length Socialtext::Page->name_to_id($page_name) ) {

        my $message = loc("Page title is too long after URL encoding");
        data_validation_error errors => [$message];
    }
    if ( length Socialtext::Page->name_to_id($page_name) == 0 ) {
        my $message = loc("Page title missing");
        data_validation_error errors => [$message];
    }
}

sub edit_content {
    my $self = shift;
    my $page_name = $self->cgi->page_name;
    my $content   = $self->cgi->page_body;

    $self->_validate_pagename_length($page_name);

    my $page = $self->hub->pages->new_from_name($page_name);
    return $self->to_display($page)
        unless $self->hub->checker->check_permission('edit');

    $page->load;

    my $append_mode = $self->cgi->append_mode || '';

    if ($self->_there_is_an_edit_contention($page, $self->cgi->revision_id)) {
        Socialtext::Events->Record({
            class => 'page',
            action => 'edit_contention',
            page => $page,
        });
        if ($append_mode eq '') {
            return $self->_edit_contention_screen($page);
        }
    }

    my $metadata = $page->metadata;

    $metadata->loaded(1);
    $metadata->update( user => $self->hub->current_user );
    $metadata->Subject($page_name);
    $metadata->Type($self->cgi->page_type);

    $page->name($page_name);
    if ($append_mode eq 'bottom') {
        $page->append($content);
    }
    elsif ($append_mode eq 'top') {
        $page->prepend($content);
    }
    else {
        $page->content($content);
    }
    my @tags = $self->cgi->add_tag;

    if (@tags) {
        $page->add_tags(@tags); # add_tags auto saves
    }
    else {
        $page->store( user => $self->hub->current_user );
        Socialtext::Events->Record({
            class => 'page',
            action => 'edit_save',
            page => $page,
        });
    }

    # Move attachments uploaded to 'Untitled Page' to the actual page
    my @attach = $self->cgi->attachment;
    for my $a (@attach) {
        my ($id, $page_id) = split ':', $a;

        # Don't move attachments that were uploaded to the correct page
        next if $page_id eq $self->hub->pages->current->id;

        my $source = $self->hub->attachments->new_attachment(
            id => $id,
            page_id => $page_id
        )->load;

        my $target = $self->hub->attachments->new_attachment(
            id => $source->id,
            filename => $source->filename,
        );
        my $target_dir = $self->hub->attachments->plugin_directory;
        $target->copy($source, $target, $target_dir);
        $target->store(
            user => $self->hub->current_user,
            dir => $target_dir,
        );
        $source->delete(
            user => $self->hub->current_user
        );
    }

    return $self->to_display($page);
}

sub edit {
    my $self = shift;

    my $page_name = $self->cgi->page_name;
    $self->_validate_pagename_length($page_name);

    return $self->hub->display->display(1);
}

sub save {
    my $self = shift;
    my $original_page_id = $self->cgi->original_page_id
        or
        Socialtext::Exception::DataValidation->throw("no original page id");
    my $page = $self->hub->pages->new_page($original_page_id);

    return $self->to_display($page)
        unless $self->hub->checker->check_permission('edit');

    $page->load;

    if ($self->_there_is_an_edit_contention($page, $self->cgi->revision_id)) {
        return $self->_edit_contention_screen($page);
    }

    my $subject = $self->cgi->subject || $self->cgi->page_title;
    # Err, this is an unreachable condition since we default to using
    # the title as stored in a hidden form variable.
    unless ( defined $subject && length $subject ) {
        Socialtext::Exception::DataValidation->throw(
            errors => [loc('A page must have a title to be saved.')] );
    }

    my $body = $self->cgi->page_body;
    unless ( defined $body && length $body ) {
        Socialtext::Exception::DataValidation->throw(
            errors => [loc('A page must have a body to be saved.')] );
    }

    my @categories =
      sort keys %{+{map {($_, 1)} split /[\n\r]+/, $self->cgi->header}};
    my @tags = $self->cgi->add_tag;
    push @categories, @tags;
    $page->update(
        content => $body,
        original_page_id => $self->cgi->original_page_id,
        revision         => $self->cgi->revision || 0,
        categories       => \@categories,
        subject          => $subject,
        user             => $self->hub->current_user,
    );
    Socialtext::Events->Record({
        class => 'page',
        action => 'edit_save',
        page => $page,
    });
    return $self->to_display($page);
}

# Build the edit contention screen
# .RETURN. The HTML for the screen
sub _edit_contention_screen {
    my $self = shift;
    my $page = shift;

    $self->screen_template('view/edit_contention');
    return $self->render_screen(
        page => $page,
        page_body => $self->html_escape($self->cgi->page_body),
        display_title => $page->title,
        header_display_title => $page->title,
        attachment_count => scalar $self->hub->attachments->all,
        revision_count => $self->hub->pages->current->metadata->Revision,
    );
}

sub _there_is_an_edit_contention {
    my $self = shift;
    my $page = shift;
    my $original_revision = shift;

    return 0 unless $page->exists;
    return 0 if $page->deleted;
    return 0 if ($page->revision_id eq $original_revision);

    # If the revision ID we got wasn't a valid page revision,
    # there's contention.
    my @revisions = $page->all_revision_ids;
    if (!grep (/^$original_revision$/, @revisions)) {
        return 1;
    }
    # Since the revision is different, pull the old page and check contents against the current page
    my $original_page = $self->hub->pages->new_page($page->id)->load_revision($original_revision);
    return ($original_page->content ne $page->content);
}

sub to_display {
    my $self = shift;
    my $page = shift;
    my $edit_mode = shift || 0;

    my $path = Socialtext::WeblogPlugin->compute_redirection_destination(
        page          => $page,
        caller_action => $self->cgi->caller_action,
    );

    if ($edit_mode) {
        $self->redirect("$path#edit");
    } else {
        $self->redirect($path);
    }
}

package Socialtext::Edit::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'Button';
cgi 'append_mode';
cgi 'caller_action';
cgi 'category';
cgi 'header';
cgi 'revision_id';
cgi 'page_type';
cgi 'original_page_id';
cgi 'page_body';
cgi 'revision';
cgi 'subject';
cgi 'summary';
cgi 'type';
cgi 'page_title';
cgi 'add_tag';
cgi 'attachment';

1;
