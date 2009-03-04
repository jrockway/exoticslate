# @COPYRIGHT@
package Socialtext::BacklinksPlugin;
use strict;
use warnings;

use base 'Socialtext::Query::Plugin';

use Class::Field qw( const );
use Socialtext::Pages;
use Socialtext::l10n qw(loc);

sub class_id { 'backlinks' }
const class_title          => 'Backlinks';
const SEPARATOR            => '____';
const MAX_FILE_LENGTH      => 255;
const preference_query     =>
      'How many backlinks to show in side pane box';
const cgi_class => 'Socialtext::Backlinks::CGI';

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(action => 'backlinks_html');
    $registry->add(action => 'show_all_backlinks');
    $registry->add(action => 'orphans_list' );
}

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    mkdir $self->_storage_directory;
    return unless $self->is_in_cgi;
    $self->_assert_database;
}

sub show_backlinks {
    my $self = shift;
    my $p = $self->new_preference('show_backlinks');
    $p->query($self->preference_query);
    $p->type('pulldown');
    my $choices = [
        0  => 0,
        5  => 5,
        10 => 10,
        25 => 25,
        50 => 50,
        100 => 100
    ];
    $p->choices($choices);
    $p->default(10);
    return $p;
}

sub box_on {
    my $self = shift;
    $self->preferences->show_backlinks->value and
        $self->hub->action eq 'display'
    ? 1 : 0;
}

sub backlinks_html {
    my $self = shift;
    $self->template_process('backlinks_box_filled.html',
        backlinks => $self->all_backlinks
    );
}

sub show_all_backlinks {
    my $self = shift;
    my $page_id = $self->cgi->page_id;
    my $page = $self->hub->pages->new_from_name($page_id);
    $self->screen_wrap(
        loc('All backlinks for "[_1]"', $page->metadata->Subject),
        $self->present_tense_description_for_page($page)
    );
}

# XXX consider sorting
sub orphans_list {
    my $self = shift;
    my $pages = $self->get_orphaned_pages();

    my %sortdir = %{ $self->sortdir };

    $self->_make_result_set( \%sortdir, $pages );

    return $self->display_results(
        \%sortdir,
        feeds => $self->_feeds($self->hub->current_workspace),
        display_title => loc('Orphaned Pages'),
    );
}

sub _make_result_set {
    my $self  = shift;
    my $sortdir = shift;
    my $pages = shift;

    if ($self->cgi->sortby) {
        $self->result_set($self->sorted_result_set($sortdir));
    }
    else {
        $self->result_set($self->new_result_set());
        $self->result_set->{predicate} = 'action=orphans_list';

        $self->push_result($_)
            for sort { $b->metadata->{Date} cmp $a->metadata->{Date} } @{$pages};
    }

    $self->result_set->{title} = loc('Orphaned Pages');
    $self->write_result_set;
}

sub update {
    my $self = shift;
    my $page = shift;

    $page = $self->hub->pages->page_with_spreadsheet_wikitext($page)
        if $page->metadata->Type eq 'spreadsheet';

    # XXX The formmatter uses current
    # REVIEW this can probably come out in new style?
    my $current = $self->hub->pages->current;

    $self->_clean_source_links($page);

    my $links = $self->_get_links($page);
    foreach my $found (@$links) {
        my $link = Socialtext::Page->name_to_id($found->{link});
        $self->_write_link($page, $link);
    }

    $self->hub->pages->current($current);
}

sub _get_links {
    my $self = shift;
    my $page = shift;

    my $hub = $self->hub;

    # XXX this borrows a lot of code from Socialtext::Formatter::WaflPhrase to
    # avoid hub confusion
    return $page->get_units(
        'wiki' => sub {
            return +{link => $_[0]->title};
        },
        'wafl_phrase' => sub {
            my $unit = shift;
            return unless $unit->method eq 'include';
            $unit->arguments =~ $unit->wafl_reference_parse;
            my ( $workspace_name, $page_title, $qualifier ) = ( $1, $2, $3 );
            # don't write interwiki includes (yet)
            return if (defined $workspace_name and $workspace_name ne $hub->current_workspace->name);
            return +{ link => $page_title };
        }
    );
} 


sub all_backlinks {
    my $self = shift;
    $self->almost_all_backlinks_for_page($self->hub->pages->current);
}

sub almost_all_backlinks_for_page {
    my $self = shift;
    my $page  = shift;

    my @all = @{$self->all_backlinks_for_page($page)};

    return \@all;
}

sub all_backlink_pages_for_page {
    my $self = shift;
    my $page = shift;
    my $new  = shift;

    return $self->_all_linked_pages_for_page($page, 'backlink', $new);
}

sub all_frontlink_pages_for_page {
    my $self = shift;
    my $page = shift;
    my $new  = shift;

    return $self->_all_linked_pages_for_page($page, 'frontlink', $new);
}

sub _all_linked_pages_for_page {
    my $self      = shift;
    my $page      = shift;
    my $type      = shift;
    my $incipient = shift;

    my $method = "_get_${type}_page_ids_for_page";

    my @pages = map { $self->hub->pages->new_page($_) } $self->$method($page);

    # REVIEW: meh, this is oogly, but it's done
    if ($incipient) {
        return ( grep { not $_->active } @pages );
    }
    else {
        return ( grep { $_->active } @pages );
    }
}

sub all_backlinks_for_page {
    my $self = shift;
    my $page  = shift;

    return [
        map { +{ page_uri => $_->uri, page_title => $_->title, page_id => $_->id } }
            sort { $b->modified_time <=> $a->modified_time }
            $self->all_backlink_pages_for_page($page)
    ];
}

sub past_tense_description_for_page {
    my $self = shift;
    my $page = shift;
    return $self->html_description($page, loc('The page had these Backlinks:'));
}

sub present_tense_description_for_page {
    my $self = shift;
    my $page = shift;
    return $self->html_description($page, loc('This page is linked to from:'));
}

sub html_description {
    my $self = shift;
    my $page = shift;
    my $text_for_when_there_are_backlinks = shift;

    my $links = $self->hub->backlinks->all_backlinks_for_page($page);
    return '<p>' . loc('The page had no Backlinks.') . '<p>'
        unless $links and @$links;
    my @items = map {
        '<li>'.$self->hub->helpers->page_display_link($_->{page_title}).'</li>'
    } @$links;
    return join "\n",
        "<p>$text_for_when_there_are_backlinks</p>",
        '<ul>',
        @items,
        '</ul>';
}

# return a list of Socialtext::Page objects that have no backlinks
sub get_orphaned_pages {
    my $self = shift;
    return [] unless $self->hub->current_workspace->real;
    my @pages = $self->hub->pages->all_active();

    my $orphans = [];
    foreach my $page (@pages) {
        my $backlinks = $self->all_backlinks_for_page( $page );
        push( @$orphans, $page ) unless scalar(@$backlinks);
    }
    return $orphans;
}

sub _assert_database {
    my $self = shift;
    return unless Socialtext::File::directory_is_empty( $self->_storage_directory );

    for my $page ($self->hub->pages->all) {
        $self->update($page);
    }

    # avoid trying to initialize the backlinks directory if no pages actually
    # have any backlinks while retaining "rm -f" compatibility:
    Socialtext::File::set_contents(
        $self->_storage_directory . '/.initialized', '');
}

sub _storage_directory {
    my $self = shift;
    return $self->plugin_directory;
}

# Get a list of page ids that link to a specific page. The ids are applicable
# to the current workspace only
# .RETURN. array of page ids
sub _get_backlink_page_ids_for_page {
    my $self = shift;
    my $page = shift;

    my $page_id = $page->id;
    my $chunk = $self->SEPARATOR . $page_id;
    my $dir = $self->_storage_directory . '/';
    my $path = $dir . "*$chunk";
    map { s/^$dir//; s/$chunk$//; $_} glob($path);
}

sub _get_frontlink_page_ids_for_page {
    my $self = shift;
    my $page = shift;

    my $page_id = $page->id;
    my $chunk = $page_id . $self->SEPARATOR;
    my $dir = $self->_storage_directory . '/';
    my $path = $dir . "$chunk*";
    map { s/^$dir//; s/^$chunk//; $_} glob($path);
}

sub _write_link {
    my $self = shift;
    my $page = shift;
    my $destination_id = shift;
    $self->_touch_index_file($page->id, $destination_id);
}

sub _touch_index_file {
    my $self = shift;
    my ($source, $dest) = @_;
    # XXX hack to avoid overly long filenames. means for the time
    # being that really long page names just don't get backlinks
    if (length($source . $dest . $self->SEPARATOR) <= $self->MAX_FILE_LENGTH) {
        my $file = $self->_get_filename($source, $dest);

        Socialtext::File::update_mtime($file);
    }
}

sub _clean_source_links {
    my $self = shift;
    my $page = shift;
    my $source = $page->id;
    my $chunk = $source . $self->SEPARATOR . '*';
    $self->_clean_links($chunk);
}

sub _clean_links {
    my $self = shift;
    my $chunk = shift;
    my $dir = $self->_storage_directory . '/';
    my $path = $dir . $chunk;
    unlink glob $path;
}

sub _get_filename {
    my $self = shift;
    my ($source, $dest) = @_;
    my $dir = $self->_storage_directory;
    "$dir/$source" . $self->SEPARATOR . $dest;
}

package Socialtext::Backlinks::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'page_id';
cgi 'sortby';
cgi 'direction';
cgi 'summaries';

1;

__END__

=head1 DESCRIPTION

Backlinks are one of the context providing devices in a wiki that make the
wiki useful in an emergent and wiki way. Other devices include recent changes
and recently viewed. Using search is helpful, but needing to use search is a
bad smell.

A backlink is a link from some other resource to the resource currently
under consideration. Knowing what links to here places information in
context, sometime creating greater understanding.

=head1 TODO

It would behoove us to eventually migrate this class to using a
database that supports multiple link types.

As it is easier to keep track of forward links, we should do that on
page:store, storing wiki links, interwiki links, and hyperlinks. Our
schema should extend to multiple link types (of course).

Users should only be displayed those links to which they have access
permission, so we should wait on the authorization framework before
proceeding on this work.

Ideally a backlink presentation would be sortable and filterable.

We should provide a TpVortex interface for kicks and giggles:
L<http://tpvortext.blueoxen.net/>.
