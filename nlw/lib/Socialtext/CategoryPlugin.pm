# @COPYRIGHT@
package Socialtext::CategoryPlugin;
use strict;
use warnings;

use base 'Socialtext::Query::Plugin';

use Class::Field qw( const field );
use Socialtext::File;
use Socialtext::Paths;
use POSIX ();
use Readonly;
use Socialtext::Permission qw( ST_ADMIN_WORKSPACE_PERM );
use Socialtext::Validate qw( validate SCALAR_TYPE USER_TYPE );
use Socialtext::Indexes ();
use URI::Escape ();
use Socialtext::l10n qw(loc);
use Socialtext::Timer;

sub class_id {'category'}
const class_title => 'Category Managment';
const cgi_class   => 'Socialtext::Category::CGI';
field 'all';
field 'categories';

sub Decode_category_email {
    my $class = shift;
    my $category = shift || return;
    $category =~ s/(?<=\w)_(?!_)/=20/g;
    $category =~ s/__/_/g;
    $category =~ s/=/%/g;
    Encode::_utf8_off($category);
    $category = $class->uri_unescape($category);
    return $category;
}

{
    Readonly my $UnsafeChars => '^a-zA-Z0-9_.-';

    sub Encode_category_email {
        my $class    = shift;
        my $category = URI::Escape::uri_escape_utf8( shift, $UnsafeChars );
        $category =~ s/%/=/g;
        $category =~ s/_/__/g;
        $category =~ s/=20/_/g;
        return $category;
    }
}

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add( action => 'category_list' );
    $registry->add( action => 'category_display' );
    $registry->add( action => 'category_delete_from_page' );
    $registry->add( wafl => 'category_list' => 'Socialtext::Category::Wafl' );
    $registry->add( wafl => 'category_list_full' => 'Socialtext::Category::Wafl' );
    $registry->add( wafl => 'tag_list' => 'Socialtext::Category::Wafl' );
    $registry->add( wafl => 'tag_list_full' => 'Socialtext::Category::Wafl' );
}

sub category_list {
    my $self = shift;
    $self->load;
    my $categories = $self->all;

    my @rows = map {
        {
            display    => $categories->{$_},
            escaped    => $self->uri_escape( $categories->{$_} ),
            page_count => $self->page_count( $categories->{$_} ),
        }
    } sort ( grep ( $_ ne 'recent changes', keys %$categories ) );

    my $is_admin = $self->hub->authz->user_has_permission_for_workspace(
        user       => $self->hub->current_user,
        permission => ST_ADMIN_WORKSPACE_PERM,
        workspace  => $self->hub->current_workspace,
    );

    $self->screen_template('view/taglistview');
    return $self->render_screen(
        display_title => loc("All Tags in Workspace"),
        rows          => \@rows,
        allow_delete  => 0,
    );
}

sub category_delete_from_page {
    my $self = shift;

    return unless $self->hub->checker->check_permission('edit');

    my $page_id = shift || $self->uri_escape($self->cgi->page_id);
    my $category = shift || $self->cgi->category;
    my $page = $self->hub->pages->new_page($page_id);

    $page->delete_tag($category);
    $page->metadata->update(user => $self->hub->current_user);
    $page->store( user => $self->hub->current_user );

    if ($self->page_count($category) == 0) {
        $self->delete(
            category => $category,
            user     => $self->hub->current_user,
        );
    }
}

sub all_visible_categories {
    my $self = shift;
    grep { $_ ne 'Recent Changes' } $self->all_categories();
}

sub all_categories {
    my $self = shift;
    $self->load;
    values %{ $self->all };
}

sub exists {
    my $self = shift;
    my $cat  = shift;

    $self->load;

    return exists $self->all->{ lc $cat };
}

sub category_display {
    my $self = shift;
    my $category = shift || $self->cgi->category;

    my %sort_map = %{ Socialtext::Query::Plugin->sortdir };

    my $rows = $self->get_page_info_for_category( $category, \%sort_map );

    my $uri_escaped_category = $self->uri_escape($category);
    my $html_escaped_category = $self->html_escape($category);

    $self->screen_template('view/category_display');
    return $self->render_screen(
        display_title          => loc("Tag: [_1]", $category),
        predicate              => 'action=category_display;category=' . $uri_escaped_category,
        rows                   => $rows,
        html_escaped_category  => $html_escaped_category,
        uri_escaped_category   => $uri_escaped_category,
        email_category_address => $self->email_address($category),
        sortdir                => \%sort_map,
        unplug_uri    => "?action=unplug;tag=$uri_escaped_category",
        unplug_phrase => loc('Click this button to save the pages with the tag [_1] to your computer for offline use.', $html_escaped_category),
    );
}

sub get_page_info_for_category {
    my $self = shift;
    my $category = shift;
    my $sort_map = shift;

    my $sort_sub = $self->_sort_closure($sort_map);

    my @rows;
    for my $page ( $self->get_pages_for_category( $category, 0 ) ) {
        my $subject = $page->metadata->Subject;

        # XXX some pages or page artifacts don't have subjects, too
        # torrid to chase. protect against the problem here
        next unless $subject;

        my $disposition = $self->hub->pages->title_to_disposition($subject);

        push @rows, {
            Subject     => $subject,
            Summary     => $page->metadata->Summary,
            page_id     => $page->id,
            page_uri    => $page->uri,
            disposition => $disposition,
            Date        => $page->metadata->Date,
            DateLocal   => $page->datetime_for_user,
            From        => $page->last_edited_by->best_full_name(
                workspace => $self->hub->current_workspace
            ),
            username       => $page->last_edited_by->username,
            revision_count => $page->revision_count,
        };
    }

    return [ sort $sort_sub @rows ];
}

# REVIEW - this is a somewhat nasty hack to use the sorting
# functionality of ST::Query::Plugin without having to inherit from
# it.
sub _sort_closure {
    my $self     = shift;
    my $sort_map = shift;

    my $sort_col;
    my $direction;
    if ($self->cgi->sortby) {
        $sort_col = $self->cgi->sortby;

        $direction =
            length $self->cgi->direction
            ? ($self->cgi->direction and $self->cgi->direction ne 'asc') ? 1 : 0
            : $sort_map->{$sort_col};
    } else {
        $sort_col = 'Date';
        $direction = 1;
    }

    return $self->_gen_sort_closure(
        $sort_map, $sort_col,
        $direction
    );
}

# This is copied verbatim from ST::Query::Plugin, which
# sucks. However, if we use that package's method, the sort sub
# doesn't work. AFAICT, it seems to be a scoping and/or namespace
# problem with the use of $a and $b. I suspect that the sort closure
# is capturing $a and $b in the package where it's defined, or something like that.
#
# Andy adds: Yes, it's a scoping/namespace issue.  However, you can get Perl to pass
# your $a/$b on the stack by providing a prototype for them, as in:
#
# sub _gen_sort_closure($$) {
#    my $a = shift;
#    my $b = shift;
#    ...
# }
sub _gen_sort_closure {
    my $self        = shift;
    my $sortdir_map = shift;
    my $sortby      = shift;
    my $direction   = shift || 0;

    $sortdir_map->{$sortby} = 1 - $direction;
    return $sortby eq 'revision_count'
      ? $direction
        ? sub { $b->{$sortby} <=> $a->{$sortby} or
                lc($a->{Subject}) cmp lc($b->{Subject}) }
        : sub { $a->{$sortby} <=> $b->{$sortby} or
                lc($a->{Subject}) cmp lc($b->{Subject}) }
      : $direction
        ? sub { lc($b->{$sortby}) cmp lc($a->{$sortby}) or
                lc($a->{Subject}) cmp lc($b->{Subject}) }
        : sub { lc($a->{$sortby}) cmp lc($b->{$sortby}) or
                lc($a->{Subject}) cmp lc($b->{Subject}) }
}

sub index {
    my $self = shift;
    $self->{index}
        ||= Socialtext::Indexes->new_for_class( $self->hub, $self->class_id );
}

sub page_count {
    my $self = shift;
    my $category = lc shift;

    my $index = $self->index->read($category);
    return scalar keys %$index;
}

sub get_pages_for_category {
    my $self = shift;
    my ( $category, $limit, $sort_style ) = @_;
    $category = lc($category);
    $sort_style ||= 'update';
    my $sort_method = "get_pages_for_category_by_$sort_style";
    my $index       = $self->index->read($category);
    my @pages       = $self->$sort_method( $index, $limit );
    return @pages;
}

sub get_pages_by_seconds_limit {
    my $self = shift;
    my $category    = shift;
    my $seconds     = shift;
    my $max_returns = shift;
    my $limit       = time - $seconds;
    Socialtext::Timer->Start('get_pages_by_seconds_limit');
    # XXX If we use some other module for this, we don't have to load
    # the massive POSIX library in Apache.
    my $date_limit_string = POSIX::strftime( '%Y%m%d%H%M%S', gmtime($limit) );

    # XXX consider some exception handling here
    my $index = $self->index->read($category);

    my @pages;

    # REVIEW: use map grep whoo ha here?
PAGE:
    for my $page_id ( sort { $index->{$b} cmp $index->{$a} || $a cmp $b }
        ( keys(%$index) ) ) {

        my $page = $self->hub->pages->new_page($page_id);
        next PAGE unless $page->active;

        last PAGE if ( defined $max_returns and --$max_returns < 0 );

        # only pay attention to date if we've not asked for a limited
        # number of returns
        if ( not defined($max_returns) ) {
            my $page_date = $index->{$page_id};

            # sometimes the index is bad, so don't use its info
            next PAGE unless ( $page_date && $page_date =~ /\A\d{14}\z/ );
            last PAGE unless $page_date > $date_limit_string;
        }
        push @pages, $page;
    }
    Socialtext::Timer->Stop('get_pages_by_seconds_limit');
    return \@pages;
}

sub get_pages_for_category_by_update {
    my $self = shift;
    my ( $index, $limit ) = @_;

    # sorts by date: value of index is Date: header in page
    my @page_ids = sort { $index->{$b} cmp $index->{$a} } keys %$index;
    my @pages;
    for my $page_id (@page_ids) {
        my $page = $self->hub->pages->new_page($page_id);
        next unless $page->active;
        $page->load;
        push @pages, $page;
        last unless --$limit;
    }
    return @pages;
}

sub get_pages_for_category_by_create {
    my $self = shift;
    my ( $index, $limit ) = @_;
    my @pages = sort {
        my $orig_b = $b->original_revision;
        my $orig_a = $a->original_revision;
        $orig_b->revision_id <=> $orig_a->revision_id
        }
        grep { $_->active }
        map  { $self->hub->pages->new_page($_) }
        keys %$index;
    my $num_entries =
          $limit - 1 > $#pages
        ? $#pages
        : $limit - 1;
    return @pages[ 0 .. $num_entries ];
}

sub get_pages_numeric_range {
    my $self = shift;
    my $category           = shift;
    my $start              = shift || 0;
    my $finish             = shift;
    my $sort_and_get_pages = shift;
    my @pages              = $self->get_pages_for_category(
        $category, $finish, $sort_and_get_pages,
    );
    @pages = @pages[ $start .. $#pages ];
    return @pages;
}

sub load {
    my $self = shift;
    my $categories = {};
    $self->all($categories);
    my $filename = $self->_dot_categories_file();
    if ( -e $filename ) {
        map {
            chomp;
            $categories->{ lc($_) } = $_;
        } Socialtext::File::get_contents_utf8($filename);
    }
    return $self;
}

sub _dot_categories_file {
    my $self = shift;
    return Socialtext::File::catfile(
        Socialtext::Paths::page_data_directory(
            $self->hub->current_workspace->name
        ),
        '.categories'
    );
}

sub save {
    my $self = shift;
    return unless $self->merge(@_);
    $self->_save;
}

sub merge {
    my $self = shift;
    $self->load;
    my $categories = $self->all;
    my $changed    = 0;
    for my $category (@_) {
        next if exists $categories->{ lc($category) };
        $categories->{ lc($category) } = $category;
        $changed++;
    }
    $self->categories($categories);
    $changed;
}

sub _save {
    my $self = shift;
    # Need to save this filehandle so the lock sticks around until
    # we're done writing.
    my $fh = Socialtext::File::write_lock( $self->_lock_file );

    my $categories = $self->categories;
    Socialtext::File::set_contents_utf8(
        $self->_dot_categories_file(),
        join '', ( map { $categories->{$_} . "\n" }
                   # XXX - why is this ever undefined?
                   grep { defined $categories->{$_} }
                   sort keys %$categories ) );

    close $fh;
}

sub _lock_file {
    my $self = shift;
    return Socialtext::File::catfile(
        Socialtext::Paths::page_data_directory(
            $self->hub->current_workspace->name
        ),
        '.categories_lock'
    );
}

{
    Readonly my $spec => {
        category => SCALAR_TYPE,
        user     => USER_TYPE,
    };

    sub delete {
        my $self = shift;
        my %p    = validate( @_, $spec );

        $self->load;
        my $categories = $self->all;

        unless ( defined $categories->{ lc $p{category} } ) {
            warn "Category not found\n";
            return;
        }

        # This should all be a transaction.
        $self->index->delete( $p{category} );

        for my $page_id ( $self->hub->pages->all_ids ) {
            my $page = $self->hub->pages->new_page($page_id);
            next
                unless grep { $_ eq $p{category} }
                @{ $page->metadata->Category };
            $page->metadata->Category(
                [
                    grep { $_ ne $p{category} } @{ $page->metadata->Category }
                ]
            );
            $page->store( user => $p{user} );
        }

        # This needs to come after messing with pages, because
        # $page->store calls this class's save() method
        delete $categories->{ lc $p{category} };
        $self->categories($categories);

        $self->_save;
    }
}

sub match_categories {
    my $self  = shift;
    my $match = shift;

    $self->load;

    return sort grep { /\Q$match\E/i } values %{ $self->all };
}

sub weight_categories {
    my $self = shift;
    my @categories = @_;

    my %data = ();

    %data = ( tags => [] );
    my $tag_db = $self->index->read_only_hash;

    my $max_count = 0;
    foreach my $tag (@categories) {
        next if ( lc($tag) eq 'recent changes' );
        my $count = keys %{ $tag_db->{lc $tag} };
        push @{ $data{tags} },
            {
            'name'   => $tag,
            'page_count' => $count,
            };
        $max_count = $count if $max_count < $count;
    }

    @{ $data{tags} } = sort {
        if ( $b->{page_count} == $a->{page_count} ) {
            return lc( $a->{tag} ) cmp lc( $b->{tag} );
        }
        else {
            return $b->{page_count} <=> $a->{page_count};
        }
    } @{ $data{tags} };

    $data{maxCount} = $max_count;

    return %data;
}

sub index_generate {
    my $self = shift;
    my $hash = {};
    for my $page_id ( $self->hub->pages->all_ids ) {
        my $page = $self->hub->pages->new_page($page_id);
        my $date_time = join '', ( $page->metadata->Date =~ /(\d+)/g );
        for my $category ( @{ $page->metadata->Category }, 'Recent Changes' ) {
            $hash->{ lc($category) }{$page_id} = $date_time;
        }
    }
    return $hash;
}

sub index_update {
    my $self = shift;
    my ( $index, $page_id, $date, $old_categories, $new_categories ) = @_;
    my $date_time = join '', ( $date =~ /(\d+)/g );

    for my $category (@$old_categories) {
        my $lcat = lc($category);
        my $entry = $index->{$lcat} || {};
        delete $entry->{$page_id};
        $index->{$lcat} = $entry;
    }
    if (scalar(grep { lc($_) eq 'recent changes'} @$new_categories) == 0) {
        push @$new_categories, 'Recent Changes';
    }
    for my $category (@$new_categories) {
        my $lcat = lc($category);
        my $entry = $index->{$lcat} || {};
        $entry->{$page_id}  = $date_time;
        $index->{$lcat} = $entry;
    }
}

sub index_delete {
    my $self = shift;
    my ( $index, $category ) = @_;
    delete $index->{ lc($category) };
}

sub email_address {
    my $self = shift;
    my $category = shift;
    return '' if $category eq 'recent changes';
    $category = $self->Encode_category_email($category);
    my $email_address = $self->hub->current_workspace->email_in_address;
    if ( !$self->hub->current_workspace->email_weblog_dot_address ) {
        $email_address =~ s/\@/\+$category\@/;
    }
    else {
        $email_address =~ s/\@/\.$category\@/;
    }
    return $email_address;
}

package Socialtext::Category::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'category';
cgi 'page_id' => '-clean_path';
cgi 'sortby';
cgi 'direction';

######################################################################
package Socialtext::Category::Wafl;

use base 'Socialtext::Query::Wafl';
use Socialtext::l10n qw(loc);

sub _set_titles {
    my $self = shift;
    my $arguments  = shift;

    my $title_info;
    if ( $arguments =~ /blog/i ) {
  
        if ( $self->target_workspace ne $self->current_workspace_name ) {
            $title_info = loc("Recent Posts from [_1] in workspace [_2]", $arguments, $self->target_workspace);
        } else {
            $title_info = loc("Recent Posts from [_1]", $arguments);
        }
    }
    else {
        if ( $self->target_workspace ne $self->current_workspace_name ) {
            $title_info = loc("Recent Changes in Tag [_1] in workspace [_2]", $arguments, $self->target_workspace);
        } else {
            $title_info = loc("Recent Changes in Tag [_1]", $arguments);
        }
    }
    $self->wafl_query_title($title_info);
    $self->wafl_query_link( $self->_set_query_link($arguments) );
}

sub _set_query_link {
    my $self = shift;
    my $arguments = shift;
    return $self->hub->viewer->link_dictionary->format_link(
        link => 'category_query',
        workspace => $self->target_workspace,
        category => $self->uri_escape($arguments),
    );
}

sub _get_wafl_data {
    my $self = shift;
    my $hub            = shift;
    my $category       = shift || '';
    my $workspace_name = shift;

    $hub = $self->hub_for_workspace_name($workspace_name);
    $hub->recent_changes->get_recent_changes_in_category(
        count    => 10,
        category => lc($category),
    );
}

1;
