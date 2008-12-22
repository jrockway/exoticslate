# @COPYRIGHT@
package Socialtext::WeblogPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use Class::Field qw( const field );
use Socialtext::Pages;
use URI;
use URI::QueryParam;
use Socialtext::l10n qw( loc );
use Encode;
use utf8;

sub class_id { 'weblog' }
const class_title => 'Weblogs';
const cgi_class => 'Socialtext::Weblog::CGI';
const default_weblog_depth => 10;
field current_weblog => '';

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(action => 'weblogs_create');
    $registry->add(action => 'weblog_display');
    $registry->add(action => 'weblog' => 'weblog_display');
    $registry->add(action => 'weblog_html');
    $registry->add(action => 'weblog_redirect');
    $registry->add(preference => $self->weblog_depth);
    $registry->add(wafl => weblog_list => 'Socialtext::Category::Wafl' );
    $registry->add(wafl => weblog_list_full => 'Socialtext::Category::Wafl' );
}

sub weblog_depth {
    my $self = shift;
    my $p = $self->new_preference('weblog_depth');
    $p->query(loc('How many posts should be displayed in weblog view?'));
    $p->type('pulldown');
    my $choices = [
        5 => '5',
        10 => '10',
        15 => '15',
        20 => '20',
        25 => '25',
        50 => '50',
    ];
    $p->choices($choices);
    $p->default($self->default_weblog_depth);
    return $p;
}

sub weblogs_create {
    my $self = shift;
    return $self->redirect('action=settings')
        unless $self->hub->checker->check_permission('edit');

    # If we have appropriate inputs, attempt to create the 
    # weblog. Otherwise display the create diaglog and any
    # errors we might know about.
    if ( $self->cgi->Button and $self->cgi->weblog_title ) {
        my $weblog_tag = $self->create_weblog( $self->cgi->weblog_title );
        unless ( $self->input_errors_found ) {
            $weblog_tag = $self->hub->pages->title_to_uri($weblog_tag);
            return $self->redirect(
                "action=weblog_display;tag=$weblog_tag" );
        }
    }
    elsif ( $self->cgi->Button and !$self->cgi->weblog_title ) {
        my $message = loc("A weblog title must be provided.");
        $self->add_error($message);
    }

    my $settings_section = $self->template_process(
        'element/settings/weblog_create',
        $self->status_messages_for_template,
    );

    $self->screen_template('view/settings');
    return $self->render_screen(
        settings_table_id => 'settings-table',
        settings_section  => $settings_section,
        hub               => $self->hub,
        display_title     => loc('Create New Weblog'),
        pref_list         => $self->_get_pref_list,
    );
}

sub _get_weblog_tag_suffix {
    my $self = shift;
    my $locale = $self->hub->best_locale;
    my $weblog_tag_suffix;
    if ($locale eq 'ja') {
        $weblog_tag_suffix = qr/ブログ$/i;
    } else {
        $weblog_tag_suffix = qr/blog$/i;
    }

    Encode::_utf8_on($weblog_tag_suffix) if not Encode::is_utf8($weblog_tag_suffix);
    return $weblog_tag_suffix;
}

sub _create_new_page_for_data_validation_error {
    my $self = shift;
    my $page_name = shift;
    my $page_id = substr(Socialtext::Page->name_to_id($page_name), 0, Socialtext::Page->_MAX_PAGE_ID_LENGTH());
    return $self->hub->pages->new_page($page_id); 
}

sub _weblog_title_is_valid {
    my $self = shift;
    my $weblog_name = shift;
    my $message;

    if (length Socialtext::Page->name_to_id($weblog_name) > Socialtext::Page->_MAX_PAGE_ID_LENGTH() ) {
       $message = loc("Weblog name is too long after URL encoding");
       $self->add_error($message);
       return 0;
    }
   
    return 1;
}

sub _first_post_title_id {
    my $self             = shift;
    my $weblog_tag       = shift;
    my $first_post_title = loc("First Post in [_1]", $weblog_tag);
    my $first_post_id    = Socialtext::Page->name_to_id($first_post_title);
    return ( $first_post_title, $first_post_id );
}

sub _create_first_post {
    my $self       = shift;
    my $weblog_tag = shift;

    my ($first_post_title, $first_post_id)
        = $self->_first_post_title_id($weblog_tag);
    return if (! $self->_weblog_title_is_valid($first_post_id));

    my $first_post = $self->hub->pages->new_page($first_post_id);
    if ( !defined $first_post ) {
        $first_post = $self->_create_new_page_for_data_validation_error(
            $weblog_tag);
    }

    my $metadata = $first_post->metadata;
    $metadata->Subject($first_post_title)
        unless $metadata->Subject;

    return $first_post;
}

=head2 create_weblog($weblog_tag)

Create a new weblog with the name C<$weblog_tag>. Unless the name ends
in C</blog$/i> append " Weblog" to the end of the tag name.  Create a
first post in the tag by creating a page tagged with the tag.

=cut

sub create_weblog {
    my $self       = shift;
    my $weblog_tag = shift;

    $weblog_tag =~ s/^\s+|\s+$//g;

    # reset errors to get around the fact that errors is effectively 
    # class level because all the object methods in plugins aren't 
    # really object methods.
    $self->errors([]);

    my $weblog_tag_suffix = $self->_get_weblog_tag_suffix();
    unless ( $weblog_tag =~ $weblog_tag_suffix ) {
        $weblog_tag = loc( "[_1] Weblog", $weblog_tag );
    }

    # If the weblog tag is already in use OR there is a similar enough tag
    # that the first post title will have the same id as an existing weblog,
    # tell the user to try again.
    for ($self->hub->category->all) {
        if ( /^\Q$weblog_tag\E/i
            || ($self->_first_post_title_id($_))[1] eq
            ($self->_first_post_title_id($weblog_tag))[1] ) {
            my $message = loc(
                "There is already a \'[_1]\' weblog. Please choose a different name.",
                $weblog_tag
            );
            $self->add_error($message);
            return;
        }
    }

    my $first_post = $self->_create_first_post($weblog_tag);
    return if (!defined $first_post);

    my $categories = $first_post->metadata->Category;
    push @$categories, $weblog_tag;

    my $content = loc(
        "This is the first post in [_1]. Click *New Post* to add another post.",
        $weblog_tag );
    $first_post->content($content);
    $first_post->metadata->update( user => $self->hub->current_user );
    $first_post->store( user => $self->hub->current_user );

    return $weblog_tag;

}

sub _feeds {
    my $self = shift;
    my $workspace = shift;

    my $feeds = $self->SUPER::_feeds($workspace);
    my $uri_root = $self->hub->syndicate->feed_uri_root($self->hub->current_workspace);
    $feeds->{rss}->{page} = {
        title => loc('Weblog: [_1] RSS', $self->current_blog_str),
        url => $uri_root . '?tag=' . $self->current_blog,
    };

    $feeds->{atom}->{page} = {
        title => loc('Weblog: [_1] Atom', $self->current_blog_str),
        url => $uri_root . '?tag=' . $self->current_blog .';type=Atom',
    };

    return $feeds;
}

sub first_blog {
    my $self = shift;
    my $weblog_tag = $self->_get_weblog_tag_suffix();
    my ($first_blog) = grep { /$weblog_tag/io }
                            $self->hub->category->all;
    $first_blog ||= 'recent changes';
    return $first_blog;
}

sub current_blog_str {
    my $self = shift;
    my $tag = $self->cgi->tag_or_category;
    $self->current_weblog($tag) && $self->update_current_weblog if $tag;
    return $tag
        || loc($self->cache->{current_weblog})
        || loc('Recent Changes');
}

sub current_blog {
    my $self = shift;
    my $tag = $self->cgi->tag_or_category;
    $self->current_weblog($tag) && $self->update_current_weblog if $tag;
    return $tag || $self->cache->{current_weblog} || 'recent changes';
}

sub current_blog_escape_uri {
    my $self = shift;
    return $self->uri_escape($self->current_blog);
}

sub current_blog_escape_html {
    my $self = shift;
    return $self->html_escape($self->current_blog);
}

sub entry_limit {
    my $self = shift;
    $self->cgi->limit || $self->default_weblog_depth;
}

sub start_entry {
    my $self = shift;
    $self->cgi->start || 0;
}

sub weblog_display {
    my $self = shift;
    my $weblog_id = $self->current_blog;
    my $weblog_start_entry = $self->start_entry;
    my $weblog_limit = $self->cgi->limit || $self->preferences->weblog_depth->value;
    $self->current_weblog($weblog_id);

    my $weblog_tag_suffix = $self->_get_weblog_tag_suffix();

    my @categories = $self->hub->category->all;
    my @blogs = map {
	{
	    display => (lc($_) eq 'recent changes' ? loc('Recent Changes') : $_),
	    escape_html => $self->html_escape($_),
	}
    } 'recent changes', (grep {/$weblog_tag_suffix/o} @categories);

    my @entries = $self->get_entries( weblog_id => $weblog_id,
        start => $weblog_start_entry, limit => $weblog_limit );

    my @sections;
    my $prev_date = '';
    for my $entry (@entries) {
        my $date =
              $self->hub->current_workspace->sort_weblogs_by_create()
            ? $entry->{original}{date}
            : $entry->{date};

        $self->assert($date);
        if ($date ne $prev_date) {
            push @sections, {
                date    => $date,
                entries => [],
            };
            $prev_date = $date;
        }
        push @{$sections[-1]->{entries}}, $entry;
    }

    my $weblog_previous;
    my $weblog_next;
    if ($weblog_start_entry > 0) {
        $weblog_previous = $weblog_start_entry - $weblog_limit;
        $weblog_previous = 0 if $weblog_previous < 0;
    }

    my $count = $self->hub->category->page_count($weblog_id);
    # We have to use ($count - 1) here because our entries are
    # numbered from 0
    if ( $weblog_limit + $weblog_start_entry < ( $count - 1 )  ) {
        $weblog_next = $weblog_start_entry + $weblog_limit;
    }

    my $blog_tag = $self->current_blog;
    my $archive = $self->hub->weblog_archive->assemble_archive($blog_tag);

    $self->update_current_weblog;
    $self->screen_template('view/weblog');
    my $is_RC = (lc($weblog_id) eq 'recent changes');
    return $self->render_screen(
        box_content_filled => $self->box_content_filled,
        archive => $archive,
        display_title => ($is_RC ? loc('Recent Changes') : loc($weblog_id)),
        sections => \@sections,
        feeds => $self->_feeds($self->hub->current_workspace),
        category => ($is_RC ? loc('Recent Changes') : $weblog_id),
        category_escaped => $self->uri_escape($weblog_id),
        is_real_category => ($is_RC ? 0 : 1),
        email_category_address => $self->hub->category->email_address($weblog_id),
        blogs => \@blogs,
        weblog_previous => $weblog_previous,
        weblog_next => $weblog_next,
        enable_weblog_archive_sidebox => Socialtext::AppConfig->enable_weblog_archive_sidebox(),
        caller_action => 'weblog_display',
        loc_lang => $self->hub->best_locale,
    );
}

=head2 get_entries({})

Returns a hash of weblog entries based on named parameters provided to
the method.

=over 4

=item weblog_id

(Required). The String representing the weblog from which to get
entries.

=item start

(Required). An integer indicating where in the available entries
to start getting entries. 0 is the most recent entry.

=item limit

(Optional). How many entries to retrieve. Defaults to entry_limit().

=item no_post

(Optional). By default the returned hash includes the HTML formatted
content of the page. Setting this to a true value will ensure this
does not happen.

=back

=cut
sub get_entries {
    my $self = shift;
    my %p = @_;
    my $weblog_id = $p{weblog_id};
    my $start = $p{start};
    my $limit = $p{limit} || $self->entry_limit;
    my $no_post = $p{no_post} || 0;

    my $attachments = $self->hub->attachments;
    my @entries;

    my @page = $self->hub->category->get_pages_numeric_range(
        $weblog_id, $start, $start + $limit,
        ( $self->hub->current_workspace->sort_weblogs_by_create ? 'create' : 'update' ),
    );

    for my $page (@page) {
        my $entry = $self->format_page_for_entry(
            no_post => $no_post,
            page => $page,
            weblog_id => $weblog_id,
            attachments => $attachments,
        );
        my $original_page = $page->original_revision;
        $entry->{is_updated}
          = $original_page->revision_id != $page->revision_id;
        if ($entry->{is_updated}) {
            $entry->{original} = $self->format_page_for_entry(
                no_post => 1,
                page => $original_page,
                weblog_id => $weblog_id,
                attachments => $attachments,
            );
        } else {
            $entry->{original} = $entry;
        }
        push @entries, $entry;
    }
    return @entries;
}

# XXX this method appears to have no test coverage
sub format_page_for_entry {
    my $self = shift;
    my %args = @_;
    my $page = $args{page};
    my $weblog_id = $args{weblog_id};
    my $attachments = $args{attachments};

    $page->load;
    my $metadata = $page->metadata;
    my ($raw_date, $raw_time) = split(/\s+/, $metadata->Date);
    my $date_local = $page->datetime_for_user || $metadata->Date;
    my ($date, $time) = ($date_local =~ /(.+) (\d+:\d+:*\d*)/);
    my $key = $date_local . $page->id;
    my $entry;
    $entry->{key} = $key;
    $entry->{page_id} = $page->id;
    $entry->{revision_id} = $page->revision_id;
    $entry->{page_uri} = $page->uri;
    $entry->{date_local} = $date_local;
    $entry->{date} = $date;
    $entry->{time} = $time;
    $entry->{raw_date} = $raw_date;
    $entry->{raw_time} = $raw_time;
    $entry->{title} = $metadata->Subject;
    $entry->{author} = $metadata->From;
    $entry->{username} = $page->last_edited_by->username;
    $entry->{post} = $page->to_html_or_default unless $args{no_post};
    $entry->{attachment_count} =
      scalar @{$attachments->all( page_id => $page->id )};

    return $entry;
}

sub weblog_html {
    my $self = shift;
    $self->template_process('element/weblog/box_filled');
}

sub box_on {
    my $self = shift;
    $self->cgi->action =~ /^weblog(_display)?$/;
}

sub box_title {
    my $self = shift;
    return loc('Weblog Navigation');
}

sub box_content_filled {
    my $self = shift;

    my $title = $self->page_title;
    if ( defined $title
         and ( length Socialtext::Page->name_to_id($title) > Socialtext::Page->_MAX_PAGE_ID_LENGTH() )
       ) {
        my $message = loc( "Page title is too long; maximum length is [_1]",
            Socialtext::Page->_MAX_PAGE_ID_LENGTH );
        return $message;
    }

    my $page = $self->hub->pages->new_from_name($title);
    return $page->to_html(($page->content||""), $page);
}

sub page_title {
    my $self = shift;

    return loc('Navigation for: [_1]', $self->current_blog_str);
}

sub page_edit_path {
    my $self = shift;
    return $self->hub->helpers->page_edit_path($self->page_title)
        . ';caller_action=weblog_display';
}

sub update_current_weblog {
    my $self = shift;
    my $cache = $self->cache;
    $cache->{current_weblog} = $self->current_weblog;
    $self->cache($cache);
}

sub cache {
    my $self = shift;

    my $value = Socialtext::MLDBMAccess::mldbm_access(
        $self->plugin_directory . '/cache.db',
        $self->hub->current_user->email_address,
        @_,
    ) || {};

    return $value;
}

sub weblog_redirect {
    my $self = shift;
    
    if ( !$self->cgi->start ) {
        # Added this exception handling instead of the Hub validation
        # because the Hub validation was causing an app error instead 
        # of displaying the error properly
        Socialtext::Exception::DataValidation->throw(
            errors => ['Unable to redirect without a start value'] );
        #$self->hub->handle_validation_error ("Unable to redirect without start value");
    }
    $self->redirect(
        $self->compute_redirection_destination_from_url( $self->cgi->start )
    );
}

sub compute_redirection_destination_from_url {
    my $self = shift;
    my $url_string = shift;

    # URI expects query parameters to be separated by &s, not ;s.
    $url_string =~ tr/;/&/;

    my $url = URI->new($url_string);
    my %parts;
    $parts{$_} = $url->query_param($_) for qw(page_name caller_action tag);

    return __PACKAGE__->compute_redirection_destination(
        page =>
            ($self->hub->pages->new_from_name($parts{page_name}) || undef),
        caller_action => $parts{caller_action},
        tag           => $parts{tag},
    );
}

sub compute_redirection_destination {
    my $self = shift;
    my %p = @_;  # tried Socialtext::Validate, but giving up after much hassle
    my $page          = $p{page};
    my $caller_action = $p{caller_action};

    return '' unless $page;

    return $page->uri unless $caller_action;
    my $path = $p{caller_action} =~ /^weblog_/
        ? "action=$caller_action"
            . ($p{tag} ? ";tag=" . $self->uri_escape($p{tag}) : '') 
            . '#' . $page->uri
        : "action=$caller_action";
    return "index.cgi?$path";
}

package Socialtext::Weblog::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'tag';
cgi 'category'; # deprecated
cgi 'Button';
cgi 'weblog_title';
cgi 'start';
cgi 'limit';

sub tag_or_category {
    my $self = shift;
    return $self->tag || $self->category;
}

1;

