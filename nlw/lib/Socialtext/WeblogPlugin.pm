# @COPYRIGHT@
package Socialtext::WeblogPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use Class::Field qw( const field );
use Socialtext::Pages;
use Socialtext::MLDBMAccess;
use URI;
use URI::QueryParam;
use Socialtext::l10n qw( loc );

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

    $self->_create_weblog
        if $self->cgi->Button;

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

sub _get_weblog_category_suffix {
    my $self = shift;
    my $locale = $self->hub->best_locale;
    my $weblog_category_suffix;
    if ($locale eq 'ja') {
        $weblog_category_suffix = qr/ブログ/;
    } else {
        $weblog_category_suffix = qr/blog/;
    }

    $weblog_category_suffix;
}

sub _create_weblog {
    my $self = shift;
    my $weblog_category = $self->cgi->weblog_title;
    my $weblog_name = $weblog_category;
    $weblog_category =~ s/^\s+|\s+$//g;

    if (length($weblog_name) < 2 or length($weblog_name) > 28) {
        my $message = loc("Weblog name must be between 2 and 28 characters long.");
        $self->add_error($message);
        return;
    }

    my $weblog_category_suffix = $self->_get_weblog_category_suffix(); 

    unless ( $weblog_category =~ /$weblog_category_suffix$/i ) {
        $weblog_category = loc("[_1] Weblog", $weblog_category);
    }

    $self->hub->category->load;
    my $all_categories = $self->hub->category->all;

    for (keys %$all_categories) {
        if (/^\Q$weblog_category\E/i) {
            my $message = loc("There is already a \'[_1]\' weblog. Please choose a different name.", $weblog_category);
            $self->add_error($message);
            return;
        }
    }

    my $first_post_title = loc("First Post in [_1]", $weblog_category);
    my $first_post_id = Socialtext::Page->name_to_id($first_post_title);
    my $first_post = $self->hub->pages->new_page($first_post_id);

    my $metadata = $first_post->metadata;
    $metadata->Subject($first_post_title)
        unless $metadata->Subject;

    my $categories = $metadata->Category;

    push @$categories, $weblog_category;

    my $content = loc("This is the first post in [_1]. Click *New Post* to add another post.", $weblog_category);
    $first_post->content($content);
    $metadata->update( user => $self->hub->current_user );
    $first_post->store( user => $self->hub->current_user );

    $self->redirect('action=weblog_display;category=' . $weblog_category);
}

sub _feeds {
    my $self = shift;
    my $workspace = shift;

    my $feeds = $self->SUPER::_feeds($workspace);
    my $uri_root = $self->hub->syndicate->feed_uri_root($self->hub->current_workspace);
    $feeds->{rss}->{page} = {
        title => loc('Weblog: [_1] RSS', $self->current_blog_str),
        url => $uri_root . '?category=' . $self->current_blog,
    };

    $feeds->{atom}->{page} = {
        title => loc('Weblog: [_1] Atom', $self->current_blog_str),
        url => $uri_root . '?category=' . $self->current_blog .';type=Atom',
    };

    return $feeds;
}

sub first_blog {
    my $self = shift;
    $self->hub->category->load;
    my ($first_blog) = grep /blog/i, sort values %{$self->hub->category->all};
    $first_blog ||= 'recent changes';
    return $first_blog;
}

sub current_blog_str {
    my $self = shift;
    $self->current_weblog($self->cgi->category) && $self->update_current_weblog
      if $self->cgi->category;
    $self->cgi->category || $self->cache->{current_weblog} || loc('recent changes');
}

sub current_blog {
    my $self = shift;
    $self->current_weblog($self->cgi->category) && $self->update_current_weblog
      if $self->cgi->category;
    $self->cgi->category || $self->cache->{current_weblog} || 'recent changes';
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

    $self->hub->category->load;
    my $categories = $self->hub->category->all;
    $categories->{'recent changes'} = loc('Recent Changes');
    my @blogs = map {
	{
	    display => $categories->{$_},
	    escape_html => $self->html_escape($categories->{$_}),
	}
    } 'recent changes', sort (grep {/blog/} keys %$categories);

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

    $self->update_current_weblog;
    $self->screen_template('view/weblog');
    return $self->render_screen(
        display_title => loc('[_1]', $weblog_id),
        sections => \@sections,
        feeds => $self->_feeds($self->hub->current_workspace),
        category => $weblog_id,
        category_escaped => $self->uri_escape($weblog_id),
        is_real_category => ($weblog_id =~ /^recent changes$/i ? 0 : 1),
        email_category_address => $self->hub->category->email_address($weblog_id),
        blogs => \@blogs,
        weblog_previous => $weblog_previous,
        weblog_next => $weblog_next,
        enable_weblog_archive_sidebox => Socialtext::AppConfig->enable_weblog_archive_sidebox(),
        caller_action => 'weblog_display',
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
    $entry->{fullname} =
        $page->last_edited_by->best_full_name( workspace => $self->hub->current_workspace );
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
    if (Socialtext::Page->_MAX_PAGE_ID_LENGTH < length($title)) {
        my $message = "Page title is too long; maximum length is " . Socialtext::Page->_MAX_PAGE_ID_LENGTH;
        return $message;
    }
    my $page = $self->hub->pages->new_from_name($title);
    return $page->to_html;
}

sub page_title {
    my $self = shift;
    return loc('Navigation for: [_1]', $self->current_blog);
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
    $parts{$_} = $url->query_param($_) for qw(page_name caller_action category);

    return __PACKAGE__->compute_redirection_destination(
        page => (
            $self->hub->pages->new_from_name( $parts{page_name} ) || undef
        ),
        caller_action => $parts{caller_action},
        category      => $parts{category},
    );
}

sub compute_redirection_destination {
    my $self = shift;
    my %p = @_;  # tried Socialtext::Validate, but giving up after much hassle
    my $page          = $p{page};
    my $caller_action = $p{caller_action};

    return '' unless $page;

    return $page->uri unless $caller_action;
    my $path =
        $p{caller_action} =~ /^weblog_/
        ? "action=$caller_action"
        . (
        $p{category}
        ? ";category=" . $self->uri_escape( $p{category} )
        : ''
        )
        . '#'
        . $page->uri
        : "action=$caller_action";
    return "index.cgi?$path";
}

package Socialtext::Weblog::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'category';
cgi 'Button';
cgi 'weblog_title';
cgi 'start';
cgi 'limit';

1;

