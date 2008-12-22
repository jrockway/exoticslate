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
use URI::Escape ();
use Socialtext::l10n qw(loc);
use Socialtext::Timer;
use Socialtext::SQL qw/:exec/;
use Socialtext::Model::Pages;

sub class_id {'category'}
const class_title => 'Category Managment';
const cgi_class   => 'Socialtext::Category::CGI';

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
    my %weighted = $self->weight_categories;
    my $tags = $weighted{tags};

    my @rows = grep { $_->{page_count} > 0 } map {
        {
            display    => $_->{name},
            escaped    => $self->uri_escape( $_->{name} ),
            page_count => $_->{page_count},
        }
    } sort { $a->{name} cmp $b->{name} } @$tags;

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
}

sub all {
    my $self = shift;

    my $dbh = sql_execute(<<EOT, 
SELECT tag FROM page_tag
    WHERE workspace_id = ?
    GROUP BY tag
    ORDER BY tag
EOT
        $self->hub->current_workspace->workspace_id,
    );

    my $tags = $dbh->fetchall_arrayref;
    return map { $_->[0] } @$tags;
}

sub add_workspace_tag {
    my $self = shift;
    my $tag  = shift;

    sql_execute(<<EOT,
INSERT INTO page_tag VALUES (?, NULL, ?)
EOT
        $self->hub->current_workspace->workspace_id, $tag,
    );

}


sub exists {
    my $self = shift;
    my $tag  = shift;

    my $result = sql_singlevalue(<<EOT,
SELECT 1 FROM page_tag
    WHERE workspace_id = ?
      AND LOWER(tag) = LOWER(?)
EOT
        $self->hub->current_workspace->workspace_id,
        $tag,
    );
    return $result;
}

sub category_display {
    my $self = shift;
    my $category = shift || $self->cgi->category;

    my $sortdir = Socialtext::Query::Plugin->sortdir;
    my $sortby = $self->cgi->sortby || 'Date';
    my $direction = $self->cgi->direction || $sortdir->{ $sortby };
    my $rows = $self->get_page_info_for_category( $category, $sortdir );

    my $uri_escaped_category = $self->uri_escape($category);
    my $html_escaped_category = $self->html_escape($category);

    $self->screen_template('view/category_display');
    return $self->render_screen(
        summaries              => $self->show_summaries,
        display_title          => loc("Tag: [_1]", $category),
        predicate              => 'action=category_display;category=' . $uri_escaped_category,
        rows                   => $rows,
        html_escaped_category  => $html_escaped_category,
        uri_escaped_category   => $uri_escaped_category,
        email_category_address => $self->email_address($category),
        sortdir                => $sortdir,
        sortby                 => $sortby,
        direction              => $direction,
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
            is_spreadsheet => $page->is_spreadsheet,
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
            ? ($self->cgi->direction and $self->cgi->direction ne 'asc') ? 'desc' : 'asc'
            : $sort_map->{$sort_col};
    } else {
        $sort_col = 'Date';
        $direction = $sort_map->{Date};
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
    my $sortdir_map = shift; # the default mapping of sortby to a direction
    my $sortby      = shift; # the attribute being sorted on
    my $direction   = shift; # the direction ('asc' or 'desc')

    if ( $sortby eq 'revision_count' ) { # The only integral attribute, so use numeric sort
        if ( $direction eq 'asc' ) {
            return sub {
                $a->{revision_count} <=> $b->{revision_count}
                    or lc( $a->{Subject} ) cmp lc( $b->{Subject} );
                }
        }
        else {
            return sub {
                $b->{revision_count} <=> $a->{revision_count}
                    or lc( $a->{Subject} ) cmp lc( $b->{Subject} );
                }
        }
    }
    elsif ( $sortby eq 'username' ) { 
        # we want to sort by whatever the system knows these users as, which
        # may not be the same as the From header.
        if ( $direction eq 'asc' ) {
            return sub {
                Socialtext::User->new( 
                    username => $a->{username} 
                )->best_full_name 
                cmp 
                Socialtext::User->new(
                    username => $b->{username}
                )->best_full_name
                or lc( $a->{Subject} ) cmp lc( $b->{Subject} );
            }
        }
        else {
            return sub {
                Socialtext::User->new( 
                    username => $b->{username} 
                )->best_full_name 
                cmp 
                Socialtext::User->new(
                    username => $a->{username}
                )->best_full_name
                or lc( $b->{Subject} ) cmp lc( $a->{Subject} );
            }
        }
    }
    else { # anything else, most likely a string
        if ( $direction eq 'asc' ) {
            return sub {
                lc( $a->{$sortby} ) cmp lc( $b->{$sortby} )
                    or lc( $a->{Subject} ) cmp lc( $b->{Subject} );
            };
        }
        else {
            return sub {
                lc( $b->{$sortby} ) cmp lc( $a->{$sortby} )
                    or lc( $a->{Subject} ) cmp lc( $b->{Subject} );
            };
        }
    }
}

sub page_count {
    my $self = shift;
    my $tag  = shift;

    my $result = sql_singlevalue(<<EOT,
SELECT count(page_id) FROM page_tag
    WHERE workspace_id = ?
      AND LOWER(tag) = LOWER(?)
EOT
        $self->hub->current_workspace->workspace_id,
        $tag,
    );
    return 0+$result;
}

sub get_pages_for_category {
    my $self = shift;
    my ( $tag, $limit, $sort_style ) = @_;
    $tag = lc($tag);
    $sort_style ||= 'update';
    my $order_by = $sort_style eq 'update' 
                        ? 'last_edit_time DESC' 
                        : 'create_time DESC';

    # Load from the database, and then map into old-school page objects
    my $model_pages = [];
    if (lc($tag) eq 'recent changes') {
        $model_pages = Socialtext::Model::Pages->All_active(
            hub          => $self->hub,
            workspace_id => $self->hub->current_workspace->workspace_id,
            order_by     => $order_by,
            ($limit ? (limit => $limit) : ()),
        );
    }
    else {
        $model_pages = Socialtext::Model::Pages->By_tag(
            hub          => $self->hub,
            workspace_id => $self->hub->current_workspace->workspace_id,
            tag          => $tag,
            order_by     => $order_by,
            ($limit ? (limit => $limit) : ()),
        );
    }
    return map { $self->hub->pages->new_page($_->id) } @$model_pages;
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

{
    Readonly my $spec => {
        tag  => SCALAR_TYPE,
        user => USER_TYPE,
    };

    sub delete {
        my $self = shift;
        my %p    = validate( @_, $spec );

        # Delete the tag on each page
        for my $page ( $self->get_pages_for_category($p{tag}) ) {
            $page->metadata->Category(
                [ grep { $_ ne $p{tag} } @{ $page->metadata->Category }
                ]
            );
            $page->store( user => $p{user} );
        }

        # Delete any workspace tags
        sql_execute( <<EOT,
DELETE FROM page_tag 
    WHERE workspace_id = ?
      AND tag = ?
EOT
            $self->hub->current_workspace->workspace_id, $p{tag},
        );
    }
}

sub match_categories {
    my $self  = shift;
    my $match = shift;

    return sort grep { /\Q$match\E/i } $self->all;
}

sub weight_categories {
    my $self = shift;
    my @tags = map {lc($_) } @_;
    my %data = (
        maxCount => 0,
        tags => [],
    );

    my $tag_args = join(',', map { '?' } @tags);
    my $tag_in = @tags ? "AND LOWER(tag) IN ($tag_args)" : '';
    my $dbh = sql_execute(<<EOT, 
SELECT tag AS name, count(page_id) AS page_count 
    FROM page_tag
    WHERE workspace_id = ?
      $tag_in
    GROUP BY tag
    ORDER BY count(page_id) DESC, tag
EOT
        $self->hub->current_workspace->workspace_id, @tags,
    );

    $data{tags} = $dbh->fetchall_arrayref({});
    my $max = 0;
    for (map { $_->{page_count} } @{ $data{tags} }) { 
        $max = $_ if $_ > $max;
        $_ += 0; # cast to number
    }
    $data{maxCount} = $max;
    return %data;
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
cgi 'summaries';

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
