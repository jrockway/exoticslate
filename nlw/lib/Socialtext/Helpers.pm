# @COPYRIGHT@
package Socialtext::Helpers;
use strict;
use warnings;

# vaguely akin to RubyOnRails' "helpers"
use Socialtext;
use base 'Socialtext::Base';
use Socialtext::l10n qw/loc/;

sub class_id { 'helpers' }

sub static_path { '/static/' . Socialtext->product_version() }
sub images_path { shift->static_path . '/images/' }

# XXX most of this should become Socialtext::Links or something

sub full_script_path {
    my $self = shift;
    '/' . $self->hub->current_workspace->name . '/index.cgi'
}

sub script_path { 'index.cgi' }

sub query_string_from_hash {
    my $self = shift;
    my %query = @_;
    return %query
      ? join '', map { ";$_=$query{$_}" } keys %query
      : '';
}

# XXX need to refactor the other stuff in this file to use this
sub script_link {
    my $self = shift;
    my $label = shift;
    my %query = @_;
    my $url = $self->script_path . '?' . $self->query_string_from_hash(%query);
    return qq(<a href="$url">$label</a>);
}

sub page_display_link {
    my $self = shift;
    my $id = shift;
    my $page = $self->hub->pages->new_from_name($id);
    return $self->page_display_link_from_page($page);
}

sub page_display_link_from_page {
    my $self = shift;
    my $page = shift;
    my $path = $self->script_path . '?' . $page->uri;
    my $title = $self->html_escape($page->metadata->Subject);
    return qq(<a href="$path">$title</a>);
}

sub page_edit_link {
    my $self = shift;
    my $page_name = shift;
    my $link_text = shift;
    my $extra = $self->query_string_from_hash(@_);
    return
        '<a href="' . $self->page_edit_path($page_name) . $extra . '">'
        . $self->html_escape($link_text)
        . '</a>';
}

sub page_display_path {
    my $self = shift;
    my $page_name = shift;
    my $path = $self->script_path();
    return $path . '?' . $page_name;
}

sub page_edit_path {
    my $self = shift;
    my $page_name = shift;
    my $path = $self->script_path();
    return $path . '?' . $self->page_edit_params($page_name)
}

# ...aaand we need this one, too.
sub page_edit_params {
    my $self = shift;
    my $page_name = shift;
    return 'action=display;page_name='
        . $self->uri_escape($page_name)
        . ';js=show_edit_div'
}

sub preference_path {
    my $self = shift;
    my $pref = shift;
    $self->script_path
        . "?action=preferences_settings;preferences_class_id=$pref"
        . $self->query_string_from_hash(@_)
}

sub global_template_vars {
    my $self = shift;

    return (
        loc               => \&loc,
        loc_lang          => $self->hub->display->preferences->locale->value,
        css               => $self->_get_css_info,
        images            => $self->_get_images_info,
        user              => $self->_get_user_info,
        wiki              => $self->_get_wiki_info,
        checker           => $self->hub->checker,
        home_is_dashboard => $self->hub->current_workspace->homepage_is_dashboard,
        customjs_uri      => $self->hub->current_workspace->customjs_uri,
        app_version       => Socialtext->product_version,
        skin_name         => $self->hub->current_workspace->skin_name,
    );
}

sub _get_css_info {
    my ($self) = @_;
    return {
        screen  => $self->hub->css->uri_for_css('screen.css'),
        print  => $self->hub->css->uri_for_css('print.css'),
        wikiwyg => $self->hub->css->uri_for_css('wikiwyg.css'),
    };
}

sub _get_images_info {
    my ($self) = @_;
    return {
        path  => $self->hub->helpers->images_path,
    };
}

sub _get_user_info {
    my ($self) = @_;
    my $user = $self->hub->current_user;
    return {
        username    => $user->guess_real_name,
        is_guest    => $user->is_guest,
    };
}

sub _get_wiki_info {
    my ($self) = @_;
    my $wiki = $self->hub->current_workspace;

    return {
        title         => $wiki->title,
        central_page  => Socialtext::Page->name_to_id( $wiki->title ),
        logo          => $wiki->logo_uri_or_default,
        name          => $wiki->name,
        has_dashboard => $wiki->homepage_is_dashboard,
        is_public     => $wiki->is_public,
        uri           => $wiki->uri,
        email_address => $wiki->email_in_address,
        static_path   => $self->static_path,
        comment_form_window_height => $wiki->comment_form_window_height,
        system_status              => $self->hub->main->status_message(),
        comment_by_email           => $wiki->comment_by_email,
        email_in_address           => $wiki->email_in_address,
    };
}

1;
