# @COPYRIGHT@
package Socialtext::Page::Base;

=head1 NAME

Socialtext::Page::Base - Base class for page objects

This code is inherited by old-style Socialtext::Page objects
AND new-style Socialtext::Model::Page objects.

=cut

use strict;
use warnings;
use Socialtext::Formatter::AbsoluteLinkDictionary;
use Socialtext::File;
use Carp ();

=head2 to_absolute_html($content)

Turn the provided $content or the content of this page into html
with the URLs formatted as fully qualified links.

As written this code modifies the L<Socialtext::Formatter::LinkDictionary>
in the L<Socialtext::Formatter::Viewer> used by the current hub. This
means that unless this hub terminates, further formats in this
session will be absolute. This is probably a bug.

=cut

sub to_absolute_html {
    my $self = shift;
    my $content = shift;

    my %p = @_;
    $p{link_dictionary}
        ||= Socialtext::Formatter::AbsoluteLinkDictionary->new();

    my $url_prefix = $self->hub->current_workspace->uri;

    $url_prefix =~ s{/[^/]+/?$}{};


    $self->hub->viewer->url_prefix($url_prefix);
    $self->hub->viewer->link_dictionary($p{link_dictionary});
    # REVIEW: Too many paths to setting of page_id and too little
    # clearness about what it is for. appears to only be used
    # in WaflPhrase::parse_wafl_reference
    $self->hub->viewer->page_id($self->id);

    if ($content) {
        return $self->to_html($content);
    }
    return $self->to_html($self->content, $self);
}

sub to_html {
    my $self = shift;
    my $content = @_ ? shift : $self->content;
    my $page = shift;
    $content = '' unless defined $content;
    return $self->is_spreadsheet
        ? $self->spreadsheet_to_html($content, $self)
        : $self->hub->viewer->process($content, $page);
}

sub spreadsheet_to_html {
    my $self = shift;
    my $content = shift;
    $content =~ s/.*\n__SPREADSHEET_HTML__\n//s;
    $content =~ s/\n__SPREADSHEET_\w+__.*/\n/s;
    return $content;
}

sub exists {
    my $self = shift;
    -e $self->file_path;
}

sub file_path {
    my $self = shift;
    join '/', $self->database_directory, $self->id;
}

sub directory_path {
    my $self = shift;
    my $id = $self->id
        or Carp::confess( 'No ID for content object' );
    return Socialtext::File::catfile(
        $self->database_directory,
        $id
    );
}

=head2 $page->all_revision_ids()

Returns a sorted list of all the revision filenames for a given page.

In scalar context, returns only the count and doesn't bother sorting.

=cut

sub all_revision_ids {
    my $self = shift;
    return unless $self->exists;

    my $dirname = $self->id;
    my $datadir = $self->directory_path;

    my @files = Socialtext::File::all_directory_files( $datadir );
    my @ids = grep defined, map { /(\d+)\.txt$/ ? $1 : () } @files;

    # No point in sorting if the caller only wants a count.
    return wantarray ? sort( @ids ) : scalar( @ids );
}

sub original_revision {
    my $self = shift;
    my $page_id  = $self->id;
    my $orig_id  = ($self->all_revision_ids)[0];
    return $self if !$page_id || !$orig_id || $page_id eq $orig_id;

    my $orig_page = ref($self)->new(hub => $self->hub, id => $page_id);
    $orig_page->revision_id( $orig_id );
    $orig_page->load;
    return $orig_page;
}

sub attachments {
    my $self = shift;

    return @{ $self->hub->attachments->all( page_id => $self->id ) };
}

sub set_mtime {
    my $self = shift;
    my $mtime = shift;
    my $filename = shift;

    (my $dirpath = $filename) =~ s#(.+)/.+#$1#;

    # Several parts of NLW look at the mtime of the page directory
    # to determine the last edit.  So if we don't change the mtimes,
    # notification emails (say) could be sent out.
    utime $mtime, $mtime, $filename 
        or warn "utime $mtime, $filename failed: $!";
    utime $mtime, $mtime, $dirpath 
        or warn "utime $mtime, $dirpath failed: $!";
}

1;
