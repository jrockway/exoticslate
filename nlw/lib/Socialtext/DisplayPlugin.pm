# @COPYRIGHT@
package Socialtext::DisplayPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use Class::Field qw( const );
use DateTime::Format::Strptime;
use Socialtext::User;
use Socialtext::String;
use Socialtext::TT2::Renderer;
use Socialtext::BrowserDetect ();
use Socialtext::l10n qw/loc system_locale/;
use Socialtext::Locales qw/available_locales/;
use JSON;
use Apache::Cookie;

$JSON::UTF8 = 1;

sub class_id { 'display' }
const class_title => loc('Screen Layout');
const maximum_header_attachments => 5;
const cgi_class => 'Socialtext::Display::CGI';

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(action => 'new_page');
    $registry->add(action => 'display');
    $registry->add(action => 'random_page');
    $registry->add(action => 'display_html');
    $registry->add(action => 'page_info');
    $registry->add(action => 'preview');
    $registry->add(preference => $self->mouseover_length);
    $registry->add(preference => $self->include_breadcrumbs);
    $registry->add(preference => $self->locale);
}

sub page_info {
    my $self = shift;

    my $page = $self->hub->pages->current;

    # UTF8 issues with *nix filename lengths
    # currently an issue may be resolved in
    # the future
    unless (defined $page) {
        Socialtext::Exception::DataValidation->throw(
            errors => [loc('Page name is too long')] );
    }

    $page->load;

    my $info = $self->_get_page_info($page);

    return JSON::objToJson($info);
}

sub new_page {
    my $self = shift;

    my $title = $self->cgi->new_blog_entry ? $self->hub->pages->new_page_title : loc('Untitled Page');
    my $page = $self->hub->pages->new_from_name($title);
    my $uri = 'action=display';

    foreach ($self->_new_tags_to_add()) {
        $uri .= ";add_tag=$_";
    }
    $uri = $uri . ';caller_action=' . $self->cgi->caller_action
        if $self->cgi->caller_action;
    $uri = $uri . ';page_name=' . $page->uri . '#edit';
    $self->redirect($uri);
}

sub preview {
    my $self = shift;
    # XXX - our html is very much not valid XML
    $self->hub->headers->content_type('text/xml');
    my $wiki_text = $self->cgi->wiki_text;
    $wiki_text =~ s/\r//g;
    $wiki_text =~ s/\n*\z/\n/;
    $self->hub->viewer->text_to_html($wiki_text);
}

# The name mouseover_length is historical. It used to allow users to
# select how many characters from the page to show. We changed it to a
# boolean as part of the UJ, but it's easiest to keep the name so that
# people who had set the preference to 0 characters have it set to
# false.
sub mouseover_length {
    my $self = shift;
    my $p = $self->new_preference('mouseover_length');
    $p->query(loc('Should hovering your mouse over a link display the first part of the page?'));
    $p->default(1);
    return $p;
}

sub include_breadcrumbs {
    my $self = shift;
    my $p = $self->new_preference('include_breadcrumbs');
    $p->query(loc('Include Recently Viewed items as a side box when viewing pages?'));
    $p->type('boolean');
    $p->default(0);
    return $p;
}

sub locale {
    my $self = shift;
    my $p = $self->new_preference('locale');
    $p->query(loc('Which language do you use?'));
    $p->type('pulldown');
    my $languages = available_locales();
    my $choices = [ map {$_ => $languages->{$_}} sort keys %$languages ];
    $p->choices($choices);

    # XXX default value should be server locale
    $p->default(system_locale());
    return $p;
}

sub random_page {
    my $self = shift;
    my $page = $self->hub->pages->random_page;

    # If no page is returned we'll show the home page.
    if ($page) {
        $self->hub->pages->current($page);
    }

    $self->hub->action('display');

    return $self->display;
}

sub _new_tags_to_add {
    my $self = shift;

    my @user_categories = $self->cgi->new_category;
    my @user_tags = $self->cgi->add_tag;
    return (@user_categories, @user_tags);
}

sub display {
    my $self = shift;
    my $start_in_edit_mode = shift || 0;

    my $page = $self->hub->pages->current;

    # Put in to deal with bots trying
    # very long and useless page names
    unless (defined $page) {
        Socialtext::Exception::DataValidation->throw(
            errors => [loc('Not a valid page name')] );
    }

    $self->log_action("DISPLAY_PAGE");

    my $renderer = Socialtext::TT2::Renderer->instance;

    my $is_new_page = $self->hub->pages->page_exists_in_workspace(
        $page->title,
        $self->hub->current_workspace->name,
    ) ? 0 : 1;

    my @new_tags = ();
    if ($is_new_page) {
        push @new_tags, $self->_new_tags_to_add();
    }
    else {
        $page->add_tags( $self->_new_tags_to_add() );
    }
    $page->load;

    my $include_recent_changes
        = $self->preferences->include_in_pages->value;

    my @recent_changes;
    if ($include_recent_changes) {
        my $depth = $self->preferences->changes_depth->value;

        @recent_changes =
            map { $self->_get_minimal_page_info($_) } @{
            $self->hub->category->get_pages_by_seconds_limit(
                'recent changes', $depth * 1440, $self->preferences->sidebox_changes_depth->value,
            )
        };
    }

    my $include_breadcrumbs = $self->preferences->include_breadcrumbs->value;

    my @breadcrumbs;
    if ($include_breadcrumbs) {
        @breadcrumbs = map { $self->_get_minimal_page_info($_) }
            $self->hub->breadcrumbs->breadcrumb_pages;
    }

    $self->hub->breadcrumbs->drop_crumb($page);
    $self->hub->hit_counter->hit_counter_increment;

    my $cookies = Apache::Cookie->fetch();
    my $st_page_accessories = (
        $cookies && $cookies->{'st-page-accessories'} &&
        $cookies->{'st-page-accessories'}->value
    ) || 'show';

    return $renderer->render(
        template => 'view/page/display',
        vars     => {
            $self->hub->helpers->global_template_vars,
            title                   => $page->title,
            page                    => $self->_get_page_info($page),
            tag_count               => scalar @{ $page->metadata->Category }, # counts recent changes!
            initialtags             => $self->_getCurrentTags($page),
            workspacetags           => $self->_get_workspace_tags,
            is_homepage             =>
                ( not $self->hub->current_workspace->homepage_is_dashboard
                    and $page->title eq
                    $self->hub->current_workspace->title ),
            is_new                  => $is_new_page,
            start_in_edit_mode      => $start_in_edit_mode,
            new_tags                => \@new_tags,
            watching                => $self->hub->watchlist->page_watched,
            login_and_edit_path => '/challenge?'
                . $self->uri_escape(
                    $self->hub->current_workspace->uri 
                  . '?action=edit;page_name=' . $page->name
                ),
            feeds => $self->_feeds( $self->hub->current_workspace, $page ),
            wikiwyg_double =>
                $self->hub->wikiwyg->preferences->wikiwyg_double->value,
            Socialtext::BrowserDetect::safari()
            ? ( raw_wikitext => $page->content )
            : (),
            current_user_workspace_count =>
                $self->hub->current_user->workspace_count,
            tools => $self->hub->registry->lookup->tool,
            include_recent_changes  => $include_recent_changes,
            recent_changes => \@recent_changes,
            include_breadcrumbs     => $include_breadcrumbs,
            breadcrumbs             => \@breadcrumbs,
            enable_unplugged        =>
                $self->hub->current_workspace->enable_unplugged,
            st_page_accessories     => $st_page_accessories,
        },
    );
}

sub _get_minimal_page_info {
    my $self = shift;
    my $page = shift;

    return {
        link   => $self->hub->helpers->page_display_path($page->id),
        title  => $self->hub->helpers->html_escape($page->title),
        date   => $page->datetime_for_user,
    }
}

sub content_only {
    my $self = shift;
    my $page = $self->hub->pages->current;

    $page->load;
    $self->log_action("DISPLAY_PAGE");
    $self->hub->breadcrumbs->drop_crumb($page);

    my $renderer = Socialtext::TT2::Renderer->instance;

    $self->hub->hit_counter->hit_counter_increment;
    return $renderer->render(
        template    => 'view/page/content',
        vars        => {
            $self->hub->helpers->global_template_vars,
            title        => $page->title,
            page         => $self->_get_page_info($page),
            initialtags  => $self->_getCurrentTags($page),
            workspacetags  => $self->_get_workspace_tags,
        },
    );
}

sub _get_page_info {
    my ( $self, $page ) = @_;

    my $original_revision = $page->original_revision;

    my $updated_author = $page->last_edited_by || $self->hub->current_user;
    my $created_author = $original_revision->last_edited_by;

    return {
        title           => $page->title,
        display_title   => Socialtext::String::html_escape( $page->title ),
        id              => $page->id,
        is_default_page => (
            $page->id eq Socialtext::Page->name_to_id(
                $self->hub->current_workspace->title
            )
        ),
        content => $self->hub->wikiwyg->html_formatting_hack(
            $page->to_html_or_default
        ),
        feeds     => $self->_feeds( $self->hub->current_workspace, $page ),
        revisions => $page->revision_count,
        revision_id => $page->revision_id || undef,
        views   => $self->hub->hit_counter->get_page_counter_value($page),
        has_stats   => $self->hub->hit_counter->page_has_stats($page),
        updated => {
            author => (
                $updated_author ? $updated_author->best_full_name(
                    workspace => $self->hub->current_workspace
                    )
                : undef
            ),
            date => $page->datetime_for_user || undef,
        },
        created => {
            author => (
                $created_author ? $created_author->best_full_name(
                    workspace => $self->hub->current_workspace
                    )
                : undef
            ),
            date => $original_revision->datetime_for_user || undef,
        },
        is_original => (  $page->revision_id
                        ? ($page->revision_id == $original_revision->revision_id)
                        : undef),
        incoming    => $self->hub->backlinks->all_backlinks_for_page($page),
        caller      => ($self->cgi->caller_action || ''),
        is_active   => $page->active,
        Socialtext::BrowserDetect::safari()
                ? (raw_wikitext => $page->content)
                : (),
    }
}

sub _date_epoch_from {
    my ($class, $date) = @_;
    my $strptime = DateTime::Format::Strptime->new(
        pattern => '%F %T %Z',
    );
    return $strptime->parse_datetime($date)->epoch;
}

sub _date_only {
    my ($class, $date) = @_;
    my $strptime = DateTime::Format::Strptime->new(
        pattern => '%F %T %Z',
    );
    return $strptime->parse_datetime($date)->ymd;
}

sub _time_only {
    my ($class, $date) = @_;
    my $strptime = DateTime::Format::Strptime->new(
        pattern => '%F %T %Z',
    );
    return $strptime->parse_datetime($date)->hms;
}

sub _get_workspace_tags {
    my $self = shift;

    my @workspace_tags = grep !/recent changes/, values %{$self->hub->category->load->all};

    my %tags = $self->hub->category->weight_categories(@workspace_tags);

    $tags{maxCount} = JSON::Number( $tags{maxCount} );

    my $text = '';
    {
        local $JSON::AUTOCONVERT = 0;
        local $JSON::SingleQuote = 0;
        my $json = JSON->new(autoconv => 0, singlequote => 0);
        foreach my $tag (@{$tags{tags}}) {
             $tag->{count} = JSON::Number($tag->{count});
        }

        $text = $json->objToJson(\%tags);
    }
    return $text;

}

sub _getCurrentTags {
    my $self = shift;
    my $page = shift;

    my %tags = $self->hub->category->weight_categories(
        @{ $page->metadata->Category } );

    foreach my $tag (@{$tags{tags}}) {
        $tag->{page_count} = JSON::Number($tag->{page_count});
    }
    $tags{maxCount} = JSON::Number($tags{maxCount});

    my $text = '';
    {
        local $JSON::AUTOCONVERT = 0;
        local $JSON::SingleQuote = 0;
        my $json = JSON->new(autoconv => 0, singlequote => 0);
        $text = $json->objToJson(\%tags);
    }
    return $text;
}

# XXX - the filtering being done here should be replaced with a
# formatter subclass or LinkDictionary that is used just when formatting
# is done for this method. See also Socialtext::Page::to_absolute_html()
sub display_html {
    my $self = shift;
    my $page = $self->hub->pages->current;
    $page->load;
    my $html = $page->to_html;
    my $title = $page->metadata->Subject;

    $html = $self->qualify_links(
        $html, $self->hub->current_workspace->uri
    );

    $self->screen_template('view/page/simple_html');
    return $self->render_screen(
        $self->hub->helpers->global_template_vars,
        html => $html,
        display_title => $title,
    );
}

sub qualify_links {
    my $self = shift;
    my $html = shift;
    my $prefix = shift;

    $html =~ s{href=(["'])((?:/|\w+\.cgi|\?).*?)\1}{href=$1$prefix$2$1}g;

    # Maybe the best thing to do is just not put the workspace on this stuff
    # in the first place?  Unfortunately, this is the only way we can be sure
    # we got 'em all:
    my ($workspace) = $prefix =~ /([^\/]+)\/?$/
        or die "That's weird - $prefix doesn't seem to have a workspace piece";
    my $overqualification = "$workspace//$workspace";
    $html =~ s/$overqualification/$workspace/g;

    return $html;
}

sub _current_categories {
    my $self = shift;
    my $hash = $self->hub->category->load->all;
    return
        map { $hash->{$_} }
        ( grep { lc($_) ne 'recent changes' } sort keys %$hash );
}

package Socialtext::Display::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'new_category';
cgi 'caller_action';
cgi 'wiki_text';
cgi 'js';
cgi 'attachment_error';
cgi 'new_blog_entry';
cgi 'add_tag';

1;
