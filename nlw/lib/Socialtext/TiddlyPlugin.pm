# @COPYRIGHT@
package Socialtext::TiddlyPlugin;
use strict;
use warnings;

# See
# http://www.socialtext.net/tiddlytext/index.cgi?tiddlywiki_template_for_socialtext
# for data structure info

use base 'Socialtext::Plugin';

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Class::Field qw( const field );
use Encode;
use File::Temp;
use Readonly;
use Socialtext::WebHelpers::Apache;
use Socialtext::AppConfig;
use Socialtext::String;

sub class_id {'tiddly'}
const class_title   => 'TiddlyText';
const cgi_class     => 'Socialtext::Tiddly::CGI';
const default_tag   => 'recent changes';
const default_count => 50;

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(action => 'unplug');
}

sub unplug {
    my $self = shift;
    my $count = $self->cgi->count() || $self->default_count();

    my $pages;

    # REVIEW: mmm, that reads well, don't it?
    if ( my $page = $self->cgi->page_name() ) {
        $pages = [ $self->hub->pages->new_from_name($page) ];
    }
    elsif ( my $tag = $self->cgi->tag() ) {
        $pages = $self->_pages_for_tag($tag);
    }
    elsif ( my $search = $self->cgi->search_term ) {
        $pages = $self->_pages_for_search($search);
    }
    elsif ( my $watchlist = $self->cgi->watchlist ) {
        $pages = $self->_pages_for_watchlist($watchlist);
    }
    elsif ( my $crumbs = $self->cgi->breadcrumbs ) {
        $pages = [ $self->hub->breadcrumbs->breadcrumb_pages() ];
    }
    else {
        $pages = $self->_pages_for_tag( $self->default_tag );
    }

    my $html = $self->produce_tiddly(
        pages => $pages,
        count => $count,
    );

    $self->_send_html($html);

    # bail out here in a way that will be okay for apache
    require Socialtext::WebApp;
    Socialtext::WebApp::Exception::ContentSent->throw();
}

=head2 produce_tiddly(%args)

Create an HTML string, including $args{count} pages
from the ordered (however you like) list of pages referenced in $args{pages}.
Tiddlers are made from each page and pushed into the tiddlytext.html
template.

=cut
sub produce_tiddly {
    my $self = shift;
    # XXX validate
    my %p = @_;

    my $pages = $p{pages};
    $pages = [ splice( @$pages, 0, $p{count} ) ];
    return $self->_create_html($pages);
}

sub _create_html {
    my $self      = shift;
    my $pages_ref = shift;
    my $tiddlers  = $self->_make_tiddlers($pages_ref);

    return $self->template_process(
        'tiddlytext/tiddlytext.html',
        workspace => $self->hub->current_workspace,
        pages     => $tiddlers,
        default   => {
            workspace => $self->hub->current_workspace->name,
            # Socialtext::URI::uri() always returns http
            # TiddlyWiki does not effectively handle redirects
            # so we need to use the protocol that this workspace
            # uses.
            server    => Socialtext::WebHelpers::Apache->base_uri(),
        },
    );
}

sub _pages_for_watchlist {
    my $self = shift;
    my $user = shift;

    if ($user eq 'default') {
        $user = $self->hub->current_user;
    } else {
        $user = Socialtext::User->new (username => $user);
    }

    my $watchlist = Socialtext::Watchlist->new(
        user      => $user,
        workspace => $self->hub->current_workspace
    );
    my @pages
        = map { $self->hub->pages->new_from_name($_) } $watchlist->pages;
    return \@pages;
}

# REVIEW: Duplication with Socialtext::SyndicatePlugin
sub _pages_for_search {
    my $self  = shift;
    my $query = shift;
    my $searcher
        = Socialtext::Search::AbstractFactory->GetFactory->create_searcher(
        $self->hub->current_workspace->name );

    my @pages = map { $self->hub->pages->new_from_name( $_->page_uri ) }
        grep { $_->isa('Socialtext::Search::PageHit') }
        $searcher->search($query);

    return \@pages;
}

sub _pages_for_tag {
    my $self = shift;
    my $tag = shift;

    # Changes this to page ids!
    return [ $self->hub->category->get_pages_for_category($tag) ];
}

sub _send_html {
    my $self = shift;
    my $html = shift;

    my $filename = join ('-', $self->hub->current_workspace->name, 'unplugged.html');
    $self->hub->headers->add_attachment(
        type => 'text/html',
        len => length($html),
        filename => $filename
    );
    $self->hub->headers->print;

    print $html;
}

sub _make_tiddlers {
    my $self      = shift;
    my $pages_ref = shift;

    my @tiddlers;

    foreach my $page (@$pages_ref) {
        push @tiddlers, $self->_tiddler_representation($page);
    }

    return \@tiddlers;
}

sub _tiddler_representation {
    my $self = shift;
    my $page = shift;

    return +{
        title => $page->metadata->Subject,
        modifier => $page->metadata->From, # REVIEW: adjust to best full name?
        modified => $self->_make_tiddly_date( $page->metadata->Date ),
        created  => $self->_make_tiddly_date(
            $page->original_revision->metadata->Date
        ),
        tags     => $self->_make_tiddly_tags( $page->metadata->Category ),
        wikitext => $self->_escape_wikitext( $page->content ),
        workspace   => $self->hub->current_workspace->name(),
        page        => $page->uri,
        # Socialtext::URI::uri() always returns http
        # TiddlyWiki does not effectively handle redirects
        # so we need to use the protocol that this workspace
        # uses.
        server      => Socialtext::WebHelpers::Apache->base_uri(),
        pageName    => $page->name,
        version     => $page->revision_id(),
    };
}

sub _escape_wikitext {
    my $self = shift;
    my $content = shift;

    $content = Socialtext::String::html_escape($content);
    $content =~ s{\\}{\\s}g;
    $content =~ s{\n}{\\n}g;
    $content =~ s{\r}{};

    return $content;
}

sub _make_tiddly_date {
    my $self        = shift;
    my $date_string = shift;

    # 2006-09-19 22:07:00 GMT

    # REVIEW: we should trap the case where no date is available
    my ( $year, $month, $day, $hour, $min, $sec )
        = ( $date_string =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):/ );

    return $year . $month . $day . $hour . $min;
}

sub _make_tiddly_tags {
    my $self = shift;
    my $tags = shift;

    my @formatted_tags;

    foreach my $tag (@$tags) {
        # filter out recent changes which sometimes is there, sometimes now
        next if lc($tag) eq 'recent changes';
        if ( $tag =~ /\s/ ) {
            $tag = "[[$tag]]";
        }
        push @formatted_tags, $tag;
    }

    return join ' ', @formatted_tags;
}
        
1;
package Socialtext::Tiddly::CGI;

use base 'Socialtext::Query::CGI';
use Socialtext::CGI qw( cgi );

cgi 'tag';
cgi 'count';
cgi 'watchlist';
cgi 'search_term';
cgi 'page_name';
cgi 'breadcrumbs';
