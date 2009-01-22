# @COPYRIGHT@
package Socialtext::Helpers;
use strict;
use warnings;
use Encode;

# vaguely akin to RubyOnRails' "helpers"
use Socialtext;
use base 'Socialtext::Base';
use Socialtext::Search::Config;
use Socialtext::Search::Set;
use Socialtext::TT2::Renderer;
use Socialtext::l10n qw/loc/;
use Socialtext::Stax;
use Apache::Cookie;

sub class_id { 'helpers' }

sub static_path { '/static/' . Socialtext->product_version() }

my $supported_format = {
    'en' => '%B %Y',
    'ja' => '%Y年 %m月',
};

sub _get_date_format {
    my $self = shift;
    my $locale = $self->hub->best_locale;
    my $locale_format = $supported_format->{$locale};
    if (!defined $locale_format) {
        $locale = 'en';
        $locale_format = $supported_format->{'en'};
    }

    return DateTime::Format::Strptime->new(
        pattern=> $locale_format,
        locale => $locale,
    );
}

sub format_date {
    my $self = shift;
    my $year = shift;
    my $month = shift;

    # Create DateTime object
    my $datetime = DateTime->new(
        time_zone => 'local',
        year => $year,
        month => $month,
        day => 1,
        hour => 0,
        minute => 0,
        second => 0
    );

    my $format = $self->_get_date_format;
    my $date_str = $format->format_datetime($datetime);
    Encode::_utf8_on($date_str);
    return $date_str;
}


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
    my $name = shift;
    my $page = $self->hub->pages->new_from_name($name);
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

sub _get_workspace_list_for_template
{
    my $self = shift;

    my @workspaces = $self->hub->current_user->workspaces->all;
    
    my @workspacelist
        =  map { +{ label => $_->title, link => "/" . $_->name } }
            @workspaces ;
    return [ sort { lc($a->{label}) cmp lc($b->{label})} @workspacelist ];
}

sub _get_history_list_for_template
{
    my $self = shift;

    my $history = $self->hub->breadcrumbs->get_crumbs;
   
    my @historylist =
        map { +{ label => $_->{page_title}, link => $_->{page_full_uri} }; }
        @$history;
    if ($#historylist > 19) { $#historylist = 19;}
    return  \@historylist;
}

sub _get_people_watchlist_for_people
{
    my $self = shift;

    my $watchlist = Socialtext::People::Profile->GetWatchlistMinimal($self->hub->current_user->user_id);

    my $result = [
        map {
            +{
                pic_url => "/data/people/" . $_->{id} . "/small_photo",
                label   => $_->{best_full_name},
                link    => "/?profile/" . $_->{id}
                }
            } @$watchlist
    ];
    return $result;
}

sub global_template_vars {
    my $self = shift;

    my $show_search_set = (
        ( $self->hub->current_user->is_authenticated )
            || ( $self->hub->current_user->is_guest
            && Socialtext::AppConfig->interwiki_search_set )
    );
    my $snippet = Socialtext::Search::Config->new()->search_box_snippet;

    my $renderer = Socialtext::TT2::Renderer->instance();

    my $search_box = $renderer->render(
        template => \$snippet,
        paths => $self->hub->skin->template_paths,
        vars => {
            current_workspace => $self->hub->current_workspace,
            show_search_set   => $show_search_set,
            search_sets       => [Socialtext::Search::Set->AllForUser(
                $self->hub->current_user
            )->all],
        }
    );


    my $cookies = Apache::Cookie->fetch();
    my %result = (
        action            => $self->hub->cgi->action,
        pluggable         => $self->hub->pluggable,
        loc               => \&loc,
        loc_lang          => $self->hub->display->preferences->locale->value,
        css               => $self->hub->skin->css_info,
        user              => $self->_get_user_info,
        wiki              => $self->_get_wiki_info,
        checker           => $self->hub->checker,
        current_workspace => $self->hub->current_workspace,
        current_page      => $self->hub->pages->current,
        home_is_dashboard =>
            $self->hub->current_workspace->homepage_is_dashboard,
        homepage_weblog =>
            $self->hub->current_workspace->homepage_weblog,
        workspace_present  => $self->hub->current_workspace->real,
        customjs           => $self->hub->skin->customjs,
        app_version        => Socialtext->product_version,
        skin_name          => $self->hub->skin->skin_name,
        search_box_snippet => $search_box,
        miki_url           => $self->miki_path,
        stax_info          => $self->hub->stax->hacks_info,
        workspaceslist     => $self->_get_workspace_list_for_template,
        ui_is_expanded     => defined($cookies->{"ui_is_expanded"}),
        $self->hub->pluggable->hooked_template_vars,
    );
    if ($self->hub->current_user->can_use_plugin('people')) {
        require Socialtext::People::Profile;
        $result{people} = $self->_get_people_watchlist_for_people;
    };

    if ($self->hub->current_user->can_use_plugin('dashboard')) {
        $result{dashboard_available} = 1;
    }
    
    # We're disabling the history global nav functionality for now, until its
    # truly global (cross workspace)
#     if ($self->hub->current_workspace->real) {
#         $result{history} = $self->_get_history_list_for_template; 
#     }

    $result{is_workspace_admin}=1 if ($self->hub->checker->check_permission('admin_workspace'));

    return %result;
}

sub miki_path {
    my ($self, $link) = @_;
    require Socialtext::Formatter::LiteLinkDictionary;

    my $miki_path      = '/lite/workspace_list';
    my $page_name      = $self->hub->pages->current->name;
    my $workspace_name = $self->hub->current_workspace->name;

    if ($workspace_name) {
        $miki_path = Socialtext::Formatter::LiteLinkDictionary->new->format_link(
            link => $link || 'interwiki',
            workspace => $workspace_name,
            page_uri  => $page_name,
            );
    }
    return $miki_path;
}

sub _get_user_info {
    my ($self) = @_;
    my $user = $self->hub->current_user;
    return {
        username          => $user->guess_real_name,
        userid            => $user->username,
        email_address     => $user->email_address,
        is_guest          => $user->is_guest,
        is_business_admin => $user->is_business_admin,
        can_use_plugin    => sub {
            $user->can_use_plugin(@_);
        },
    };
}

# This function is called in the ControlPanel
sub skin_uri { 
    my $skin_name  = shift;
    my $skin = Socialtext::Skin->new(name => $skin_name);
    return $skin->skin_uri();
}

sub _get_wiki_info {
    my ($self) = @_;
    my $wiki = $self->hub->current_workspace;
    my $skin = $self->hub->skin->skin_name;

    return {
        title         => $wiki->title,
        central_page  => Socialtext::Page->name_to_id( $wiki->title ),
        logo          => $wiki->logo_uri_or_default,
        name          => $wiki->name,
        has_dashboard => $wiki->homepage_is_dashboard,
        is_public     => $wiki->permissions->is_public,
        uri           => $wiki->uri,
        skin          => $skin,
        email_address => $wiki->email_in_address,
        static_path   => $self->static_path,
        skin_uri      => \&skin_uri,
        comment_form_window_height => $wiki->comment_form_window_height,
        system_status              => $self->hub->main ?
            $self->hub->main->status_message() : undef,
        comment_by_email           => $wiki->comment_by_email,
        email_in_address           => $wiki->email_in_address,
    };
}

1;
