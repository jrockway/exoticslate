# @COPYRIGHT@
package Socialtext::Formatter::WaflPhrase;
use strict;
use warnings;

use base 'Socialtext::Formatter::Wafl', 'Socialtext::Formatter::Phrase';

use Class::Field qw( const field );
use Socialtext::Paths;
use Socialtext::Permission 'ST_READ_PERM';

const formatter_id  => 'wafl_phrase';
const pattern_start =>
    qr/(^|(?<=[\s\-]))(".+?")?\{[\w-]+(?=[\:\ \}])(\s*:)?\s*.*?\}(?=[^A-Za-z0-9]|\z)/;
const wafl_reference_parse => qr/^\s*(?:([\w\-]+)?\s*\[(.*?)\])?\s*(\S.*?)?\s*$/;
field 'method';
field 'arguments';
field 'label';
field error => '';

sub html_start { '<span class="nlw_phrase">'}

sub html_end {
    my $self   = shift;
    my $widget = ''
        . ( $self->label ? '"' . $self->escape_wafl_dashes($self->label) . '"' : '' ) . '{'
        . $self->method
        . (
        $self->arguments
        ? ': ' . $self->escape_wafl_dashes( $self->arguments )
        : ''
        )
        . '}';
    $self->hub->wikiwyg->generate_phrase_widget_image($widget);
    return "<!-- wiki: $widget --></span>";
}

sub match {
    my $self = shift;
    return unless $self->SUPER::match(@_);

    my $label_re = qr/"(.+?)"/;
    my $wafl_re  = qr/\{([\w\-]+)(?:\s*\:)?\s*(.*)\}/;
    if ( $self->matched =~ /^${label_re}${wafl_re}$/ ) {
        $self->label($1);
        $self->arguments($3);
        my $method = lc $2;
        $method =~ s/-/_/g;
        $self->method($method);
    }
    elsif ( $self->matched =~ /^${wafl_re}$/ ) {
        $self->arguments($2);
        my $method = lc $1;
        $method =~ s/-/_/g;
        $self->method($method);
    }
}

sub set_error {
    my $self = shift;
    $self->error(shift);
    0;
}

sub syntax_error {
    my $self = shift;
    my $text = shift || $self->label || $self->arguments;
    return qq[<span class="wafl_syntax_error">$text</span>];
}

sub permission_error {
    my $self = shift;
    my $text = shift || $self->label || $self->arguments;
    return qq[<span class="wafl_permission_error">$text</span>];
}

sub existence_error {
    my $self = shift;
    my $text = shift || $self->label || $self->arguments;
    return qq[<span class="wafl_existence_error">$text</span>];
}

sub parse_wafl_reference {
    my $self = shift;
    $self->arguments =~ $self->wafl_reference_parse or return;
    my ( $workspace_name, $page_title, $qualifier ) = ( $1, $2, $3 );
    $workspace_name ||= $self->current_workspace_name;
    # XXX this just feels wrong. It's necessary for the many ways
    # we might enter the formatter. This is probably the wrong place
    # for this.
    my $page_id = Socialtext::Page->name_to_id($page_title)
        || $self->hub->viewer->page_id || $self->current_page_id;
    my $title = $page_title || '';

    # XXX using hub here may causes issues with page titles
    # from other workspaces
    return (
        $workspace_name, $title, $qualifier,
        $page_id,      Socialtext::Pages->id_to_uri($page_id)
    );
}

sub parse_wafl_category {
    my $self = shift;
    $self->arguments =~ /^\s*(?:([\w\-]+)\s*;)?\s*(\S.*?)?\s*$/
        ? ( $1, $2 )
        : ();
}

sub hub_for_workspace_name {
    my $self = shift;
    my $workspace_name = shift;

    my $hub = $self->hub;
    if ( $workspace_name ne $self->current_workspace_name ) {
        my $main = Socialtext->new();
        $main->load_hub(
            current_user      => Socialtext::User->SystemUser(),
            current_workspace => Socialtext::Workspace->new( name => $workspace_name ),
        );
        $main->hub->registry->load;

        $hub = $main->hub;
    }

    return $hub;
}

sub get_file_id {
    my $self = shift;    # XXX maybe belongs in Socialtext::Attachments
    my ( $workspace_name, $page_id, $filename ) = @_;

    my $ws = Socialtext::Workspace->new( name => $workspace_name );
    return $self->set_error( $self->permission_error )
        unless $ws && $self->authz->user_has_permission_for_workspace(
            user       => $self->current_user,
            permission => ST_READ_PERM,
            workspace  => $ws,
        );

    my $path = Socialtext::Paths::plugin_directory($workspace_name);

    my $hub = $self->hub_for_workspace_name($workspace_name);

    my $all = $hub->attachments->all( page_id => $page_id );

    $filename = lc($filename);
    my @attachments = sort { $b->Date cmp $a->Date }
        grep { lc( $_->filename ) eq $filename } @$all
        or return $self->set_error( $self->existence_error );

    $attachments[0]->id;
}

################################################################################
package Socialtext::Formatter::WaflPhraseDiv;
use base 'Socialtext::Formatter::WaflPhrase';

sub html_start {
    my $page = $Socialtext::Formatter::Viewer::in_paragraph ? '</p>' : '';
    return qq($page<div class="nlw_phrase">);
}

sub html_end {
    my $self = shift;
    my $widget = '{' . $self->method . ': ' .
        $self->escape_wafl_dashes( $self->arguments ) . '}';
    $self->hub->wikiwyg->generate_phrase_widget_image($widget);
    return "<!-- wiki: $widget\n--></div>";
}

################################################################################
package Socialtext::Formatter::WaflPhraseDivP;
use base 'Socialtext::Formatter::WaflPhrase';

sub html_start {
    my $page = $Socialtext::Formatter::Viewer::in_paragraph ? '</p>' : '';
    return qq($page<span class="nlw_phrase">);
}

sub html_end {
    my $self = shift;
    my $widget = '{' . $self->method . ': ' .
        $self->escape_wafl_dashes( $self->arguments ) . '}';
    $self->hub->wikiwyg->generate_phrase_widget_image($widget);
    my $page = $Socialtext::Formatter::Viewer::in_paragraph ? '<p>' : '';
    my $space = Socialtext::BrowserDetect::ie() ?  "&nbsp;" : "";
    return "<!-- wiki: $widget --></span>$space$page";
}

################################################################################
package Socialtext::Formatter::Image;

use base 'Socialtext::Formatter::WaflPhrase';
use Class::Field qw( const );

const wafl_id => 'image';

sub html {
    my $self = shift;
    my ( $workspace_name, $page_title, $image_name, $page_id, $page_uri )
        = $self->parse_wafl_reference;

    return $self->syntax_error unless $image_name;

    my $file_id = $self->get_file_id( $workspace_name, $page_id, $image_name )
        or return $self->error;
    $image_name     = $self->uri_escape($image_name);

    # We have to save and restore the current workspace so we can set it
    # properly for inter-workspace links.  This is probably a bug in
    # Socialtext::Attachment::full_path.
    my $old_current_workspace = $self->hub->current_workspace;
    $self->hub->current_workspace(
        Socialtext::Workspace->new( name => $workspace_name ) );
    my $link = $self->hub->viewer->link_dictionary->format_link(
        link       => 'image',
        url_prefix => $self->url_prefix,
        workspace  => $workspace_name,
        filename   => $image_name,
        page_uri   => $page_uri,
        id         => $file_id,
        full_path  => $self->hub->attachments->new_attachment(
            id       => $file_id,
            page_id  => $page_id,
            filename => $image_name,
            )->full_path,
    );
    $self->hub->current_workspace($old_current_workspace);

    return qq{<a href="$link">} . $self->label ."</a>"
        if $self->label;

    my $alt_text = $self->uri_unescape($image_name);
    return
        qq{<img alt="$alt_text" src="$link" />};
}

################################################################################
package Socialtext::Formatter::File;

use base 'Socialtext::Formatter::WaflPhrase';
use Class::Field qw( const );

const wafl_id => 'file';

sub html {
    my $self = shift;
    my ( $workspace_name, $page_title, $file_name, $page_id, $page_uri )
        = $self->parse_wafl_reference;
    return $self->syntax_error unless $file_name;

    my $label;
    if ( $self->label ) {
        $label = $self->label if $self->label;
    }
    else {
        $label = $file_name;
        $label = "[$page_title] $label"
            if $page_title
            and ( $self->current_page_id ne
            Socialtext::Page->name_to_id($page_title) );
        $label = "$workspace_name:$label"
            if $workspace_name
            and ( $self->current_workspace_name ne $workspace_name );
    }

    my $file_id = $self->get_file_id( $workspace_name, $page_id, $file_name )
        or return $self->error;

    $file_name      = $self->uri_escape($file_name);
    my $link = $self->hub->viewer->link_dictionary->format_link(
        link       => 'file',
        url_prefix => $self->url_prefix,
        workspace  => $workspace_name,
        filename   => $file_name,
        page_uri   => $page_uri,
        id         => $file_id,
    );

    return
        qq{<a href="$link">$label</a>};
}

################################################################################
package Socialtext::Formatter::HtmlPage;

use base 'Socialtext::Formatter::WaflPhrase';
use Class::Field qw( const );

const wafl_id => 'html_page';

sub html {
    my $self = shift;
    my ( $workspace_name, $page_title, $file_name, $page_id, $page_uri )
        = $self->parse_wafl_reference;
    return $self->syntax_error unless $file_name;

    my $file_id = $self->get_file_id( $workspace_name, $page_id, $file_name )
        or return $self->error;

    my $label = $file_name;
    $label = "[$page_title] $label"
        if $page_title
        and ( $self->current_page_id ne
        Socialtext::Page->name_to_id($page_title) );
    $label = "$workspace_name:$label"
        if $workspace_name
        and ( $self->current_workspace_name ne $workspace_name );

    my $link = $self->hub->viewer->link_dictionary->format_link(
        link       => 'file',
        url_prefix => $self->url_prefix,
        workspace  => $workspace_name,
        filename   => $file_name,
        page_uri   => $page_uri,
        id         => $file_id,
    );

    return
        qq{<a href="$link;as_page=1" target="_blank">$label</a>};
}

################################################################################
package Socialtext::Formatter::CSS;

use base 'Socialtext::Formatter::WaflPhrase';
use Class::Field qw( const );

const wafl_id => 'css_include';

# REVIEW: Opportunities for refactoring with html_file and image and
# file wafl. They all do essentially the same thing with slightly
# different link settings.
sub html {
    my $self = shift;
    my ( $workspace_name, $page_title, $file_name, $page_id, $page_uri )
        = $self->parse_wafl_reference;

    return $self->syntax_error unless $file_name;

    my $file_id = $self->get_file_id( $workspace_name, $page_id, $file_name )
        or return $self->error;

    my $link = $self->hub->viewer->link_dictionary->format_link(
        link       => 'file',
        url_prefix => $self->url_prefix,
        workspace  => $workspace_name,
        filename   => $file_name,
        page_uri   => $page_uri,
        id         => $file_id,
    );
    return qq{<link rel="stylesheet" type="text/css" href=}
        . qq{"$link" />};
}

################################################################################
# XXX just other pages, maybe in another workspace, for now...
# could also do web pages etc
package Socialtext::Formatter::PageInclusion;

use base 'Socialtext::Formatter::WaflPhraseDivP';
use Class::Field qw( const );
use Socialtext::Permission qw(ST_READ_PERM ST_EDIT_PERM);
use Socialtext::l10n qw( loc );

const wafl_id => 'include';

sub html {
    my $self = shift;
    my ( $workspace_name, $page_title, $section_id, $page_id, $page_uri )
        = $self->parse_wafl_reference;

    return $self->syntax_error unless $page_title;

    my $ws = Socialtext::Workspace->new( name => $workspace_name );
    return $self->permission_error
        unless $ws && $self->authz->user_has_permission_for_workspace(
            user       => $self->current_user,
            permission => ST_READ_PERM,
            workspace  => $ws,
        );

    my $edit_perm = $self->authz->user_has_permission_for_workspace(
        user       => $self->current_user,
        permission => ST_EDIT_PERM,
        workspace  => $ws,
    );

    # When we format an included page, viewer->page_id gets clobbered
    # because we don't make a new viewer object, just reuse the
    # one that already exists. So we need to save away what
    # is already set to put it back later.
    # REVIEW: hack to keep our state of in_paragraph lined up properly
    # when we format an included page
    local $Socialtext::Formatter::Viewer::in_paragraph;
    my $viewer_page_id = $self->hub->viewer->page_id;
    my $html = $self->hub->pages->html_for_page_in_workspace(
        $page_id,
        $workspace_name,
    );
    $html = $self->_strip_outer_div($html);
    $self->hub->viewer->page_id($viewer_page_id);
    return $self->html_escape($self->matched) unless $html;

    # bz 127.  We can either construct a URL with "?Foo%20Bar" as the page
    # query parameter OR we can construct it with "?foo_bar".  However, the
    # latter has unwanted consequences (c.f. bz 127) if the page doesn't exist
    # and someone clicks on the URL.  So, we check if the page exists and use
    # the right format.
    my $page_exists
        = $self->_included_page_exists( $workspace_name, $page_uri );
    my $page_uri_for_url
        = $self->uri_escape( $page_exists ? $page_uri : $page_title );

    my $view_url = $self->hub->viewer->link_dictionary->format_link(
        link       => 'interwiki',
        workspace  => $workspace_name,
        page_uri   => $page_uri_for_url,
        url_prefix => $self->url_prefix,
    );

    my $edit_url;
    if ($edit_perm) {
        eval {
            $edit_url = $self->hub->viewer->link_dictionary->format_link(
                link       => 'interwiki_edit',
                workspace  => $workspace_name,
                page_uri   => $page_uri_for_url,
                url_prefix => $self->url_prefix,
            );
        };
    }

    my $incipient_class = $page_exists ? "" : "class=\"incipient\"";

    my $link = "<a href='$view_url' $incipient_class>$page_title</a>";

    my $edit_icon = '';
    if ($edit_url) {
        my $edit = loc('edit');
        if ($edit eq 'edit') {
            my $img_path = $self->hub->helpers->images_path;
            my $icon_url = "$img_path/st/homepage/edit-icon.gif";
            $edit = "<img src='$icon_url' border='0'/>";
        }
        else {
            $edit = "$edit";
        }
        $edit_icon = "<a class='wiki-include-edit-link' href='$edit_url' $incipient_class>$edit</a>";
    }

    return qq(<div class="wiki-include-page">\n)
        . qq(<div class="wiki-include-title">$link $edit_icon</div>\n)
        . qq(<div class="wiki-include-content">$html</div></div>);
}

sub _included_page_exists {
    my ( $self, $ws_name, $page_uri ) = @_;
    my $exists = 0;

    # If any thing fails we just assume the page does not exist.
    eval {
        $self->hub->with_alternate_workspace(
            Socialtext::Workspace->new( name => $ws_name ),
            sub {
                my $page = Socialtext::Page->new( 
                    id => $page_uri,
                    hub => $self->hub 
                );
                $exists = $page->exists;
            }
        );
    };

    return $exists;
}

sub _strip_outer_div {
    my $self = shift;
    my $html = shift;
    return unless $html;
    $html =~ s/\A<div[^>]+>//;
    $html =~ s/<\/div>\n*\z//;
    return $html;
}

################################################################################
package Socialtext::Formatter::InterWikiLink;

use base 'Socialtext::Formatter::WaflPhrase';
use Class::Field qw( const );
use Socialtext::Permission 'ST_READ_PERM';
use Socialtext::l10n qw( loc );

const wafl_id => 'link';

sub html {
    my $self = shift;
    my ( $workspace_name, $page_title, $section_id, $page_id, $page_uri )
        = $self->parse_wafl_reference;

    return $self->syntax_error unless $page_title || $section_id;

    my $label        = $self->label || '';
    my $link_title   = '';
    my $section_text = '';
    if ($section_id) {
        $label ||= $page_title
            ? "$page_title ($section_id)"
            : $section_id;
        $section_id   = Socialtext::Page->name_to_id($section_id);
        $section_text = '#' . Socialtext::Formatter::legalize_sgml_id($section_id);
        $link_title   = loc("section link");
    }
    else {
        $label      ||= $page_title;
        $link_title = loc("inter-workspace link: [_1]", $workspace_name);
    }

    my $ws = Socialtext::Workspace->new( name => $workspace_name );
    return $self->permission_error($label)
        unless $ws && $self->authz->user_has_permission_for_workspace(
            user       => $self->current_user,
            permission => ST_READ_PERM,
            workspace  => $ws,
        );

    if (
        $page_title
        and not Socialtext::Pages->page_exists_in_workspace(
            $page_title,
            $ws->name,
        )
        ) {
        $page_uri = Socialtext::Pages->title_to_uri($page_title);
    }

    my $url = $page_title
        ? $self->_interwiki_url(
            $ws->name, $page_uri, $section_text,
        )
        : $section_text;

    $link_title = $self->html_escape($link_title);
    $label = $self->html_escape($label);
    $url = $self->html_escape($url);
    return qq{<a title="$link_title" href="$url">$label</a>};
}

sub _interwiki_url {
    my $self = shift;
    my $workspace_name = shift;
    my $page_uri       = shift;
    my $section_text   = shift;
    my $link           = $self->hub->viewer->link_dictionary->format_link(
        link       => 'interwiki',
        workspace  => $workspace_name,
        page_uri   => $page_uri,
        section    => $section_text,
        url_prefix => $self->url_prefix,
    );

    return $link;
}

################################################################################
package Socialtext::Formatter::CategoryLink;

use base 'Socialtext::Formatter::WaflPhrase';
use Class::Field qw( const );
use Socialtext::Permission 'ST_READ_PERM';
use Socialtext::l10n qw( loc );

const wafl_id => 'category';
my $wafl_id_str_category = loc('category');

sub html {
    my $self = shift;
    my ( $workspace_name, $category ) = $self->parse_wafl_category;
    return $self->syntax_error unless $category;
    $workspace_name ||= $self->current_workspace_name;

    my $ws = Socialtext::Workspace->new( name => $workspace_name );
    return $self->permission_error($category)
        unless $ws && $self->authz->user_has_permission_for_workspace(
            user       => $self->current_user,
            permission => ST_READ_PERM,
            workspace  => $ws,
        );

    return $self->_link_to_action_display(
        action         => $self->wafl_id,
        url_prefix     => $self->url_prefix,
        workspace_name => $workspace_name,
        category       => $category,
    );
}

sub _link_to_action_display {
    my $self = shift;
    my %p = @_;

    my $escaped_category = $self->uri_escape( $p{category} );

    my $link = $self->hub->viewer->link_dictionary->format_link(
        link       => $p{action},
        workspace  => $p{workspace_name},
        category   => $escaped_category,
        url_prefix => $p{url_prefix},
    );

    my $label = $self->label || $p{category};
    my $title = loc("[_1] link", loc($p{action}));
    return qq(<a title="$title" href="$link">$label</a>);
}

################################################################################
package Socialtext::Formatter::TagLink;

use base 'Socialtext::Formatter::CategoryLink';
use Class::Field qw( const );
use Socialtext::l10n qw( loc );

const wafl_id => 'tag';
my $wafl_id_str_tag = loc('tag');

################################################################################
package Socialtext::Formatter::WeblogLink;

use base 'Socialtext::Formatter::CategoryLink';
use Class::Field qw( const );
use Socialtext::l10n qw( loc );

const wafl_id => 'weblog';
#const wafl_id_str => loc('weblog');

################################################################################
package Socialtext::Formatter::TradeMark;

use base 'Socialtext::Formatter::WaflPhrase';
use Class::Field qw( const );

const wafl_id => 'tm';

sub html {
    return '&trade;';
}

################################################################################
package Socialtext::Formatter::TeleType;

use base 'Socialtext::Formatter::WaflPhrase';
use Class::Field qw( const );

const wafl_id => 'tt';

sub html {
    my $self = shift;
    return '<tt>' . $self->html_escape( $self->arguments ) . '</tt>';
}

################################################################################
package Socialtext::Formatter::Toc;

use base 'Socialtext::Formatter::WaflPhraseDiv';
use Class::Field qw( const );
use Socialtext::Permission 'ST_READ_PERM';
use Socialtext::l10n qw( loc );

const wafl_id => 'toc';

sub html {
    my $self = shift;
    my ( $workspace_name, $page_title, $section_id, $page_id, $page_uri )
        = $self->parse_wafl_reference;

    my $ws = Socialtext::Workspace->new( name => $workspace_name );
    return $self->permission_error
        unless $ws && $self->authz->user_has_permission_for_workspace(
            user       => $self->current_user,
            permission => ST_READ_PERM,
            workspace  => $ws,
        );

    my $hub = $self->hub_for_workspace_name($workspace_name);
    my $cur_page = $hub->pages->new_page($page_id);
    my $cur_page_title = $cur_page->title;

    return $self->syntax_error if not $cur_page_title;

    return $self->_parse_page_for_headers(
        $workspace_name, $page_id,
        $page_title
    );
}

sub _parse_page_for_headers {
    my $self              = shift;
    my $workspace_name    = shift;
    my $page_id           = shift;
    my $remote_page_title = shift;

    my $cur_page_id = $self->hub->pages->current->id;

    my $hub = $self->hub_for_workspace_name($workspace_name);
    my $page = $hub->pages->new_page($page_id);
    my $page_title = $page->title;

    my $content = $self->hub->wikiwyg->cgi->content;
    if ($content && ($cur_page_id eq $page_id || !$page->exists)) {
        $page->content($content) if $content;
    }

    my $page_url = $self->hub->viewer->link_dictionary->format_link(
        link       => 'interwiki',
        workspace  => $workspace_name,
        page_uri   => $page_id,
        url_prefix => $self->url_prefix,
    );

    my $title = loc('Contents');

    my $linkref = '';
    if ($self->current_workspace_name ne $workspace_name) {
        $title .= ": $workspace_name: {link: $workspace_name [$remote_page_title]}";
        $linkref = "$workspace_name [$remote_page_title]";
    }
    elsif ($cur_page_id ne $page_id || !$page->exists) {
        $remote_page_title ||= $self->hub->wikiwyg->cgi->page_name;
        $title .= ": [$remote_page_title]";
        $linkref = "[$remote_page_title]";
    }

    my $headers = $page->get_headers();
    my $error;
    my $wikitext = '';

    if (@$headers) {
        my $min;
        for my $header (@$headers) {
            $min = $header->{level} if not defined $min or $header->{level} < $min;
        }

        # create a list describing the headers
        foreach my $header (@$headers) {
            my $stars = '*' x ($header->{level} - ($min-1));
            $wikitext .= "$stars {link: $linkref $header->{text}}\n";
        }
    }
    else {
        $error = loc(
            "[_1] does not have any headers.",
            "<a href='$page_url'>$page_title</a>",
        );
    }

    my $html = $self->hub->viewer->text_to_html($wikitext);

    # Since we say which page this toc was generated for in the title, remove
    # all the page_name(...) parts of links
    $html =~ s/\Q$page_title\E \((.*)\)/$1/g;

    return $self->template->process(
        'wafl_box.html',
        wafl_title       => $title,
        error            => $error,
        wafl_html        => $html,
    );
}


1;
