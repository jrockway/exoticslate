# @COPYRIGHT@
package Socialtext::Search::KinoSearch::Indexer;
use strict;
use warnings;

use Class::Field qw(field);
use File::Path;
use KinoSearch::Index::Term;
use KinoSearch::InvIndexer;
use Readonly;

use Socialtext::Hub;
use Socialtext::Workspace;
use Socialtext::Page;
use Socialtext::Attachments;
use Socialtext::Log qw(st_log);
use base 'Socialtext::Search::Indexer';

# Constants for aquiring a lock.
Readonly our $LOCK_WAIT    => 1;  # Wait this many seconds before retrying.

field 'analyzer';
field 'hub';
field 'index';
field 'indexer';
field 'language';
field 'speced' => 0;
field 'workspace';

sub new {
    my ( $class, $ws_name, $language, $index, $analyzer ) = @_;
    my $self = bless {}, $class;

    $self->analyzer($analyzer);
    $self->index($index);
    $self->language($language);
    $self->workspace($ws_name);

    # Create hub
    my $ws = Socialtext::Workspace->new( name => $ws_name );
    die "Cannot create workspace '$ws_name'" unless defined $ws;
    $self->hub( Socialtext::Hub->new( current_workspace => $ws ) );
    _debug("Loaded Hub with workspace '$ws_name'.");

    # This is a bit redundant here, as we'll do it again later on the various
    # index_* methods.  However, this is required so create_indexer() actually
    # initializes the index.  This is used by the Searcher, so it can be sure
    # the index always exists before searching.
    unless ( -e $self->index ) {
        $self->_init_indexer();
        $self->_finish();
    }

    return $self;
}

######################
# Workspace Handlers
######################

# Make sure we're in a valid workspace, then recreate the index and get all
# the active pages, add each of them, and then add all the attachments on each
# page. 
sub index_workspace {
    my ( $self, $ws_name ) = @_;
    $self->_assert_right_ws($ws_name);
    $self->_init_indexer("recreate index");
    _debug("Starting to retrieve page ids to index workspace.");
    for my $page_id ( $self->hub->pages->all_ids ) {
        my $page = $self->_load_page($page_id) || next;
        $self->_add_page_doc($page);
        $self->_index_page_attachments($page);
    }
    $self->_finish( optimize => 1 );
}

# Delete the index directory.
sub delete_workspace {
    my ( $self, $ws_name ) = @_;
    $self->_assert_right_ws($ws_name);
    File::Path::rmtree( $self->index );
    _debug( "Removed " . $self->index );
}

# Get all the active attachments on a given page and add them to the index.
sub _index_page_attachments {
    my ( $self, $page ) = @_;
    _debug( "Retrieving attachments from page: " . $page->id );
    my $attachments = $page->hub->attachments->all( page_id => $page->id );
    _debug( sprintf "Retreived %d attachments", scalar @$attachments );
    for my $attachment (@$attachments) {
        $self->_add_attachment_doc($attachment);
    }
}

# Make sure the workspace this instance was created for is the one it's
# operating on.
sub _assert_right_ws {
    my ( $self, $ws_name ) = @_;
    my $this_name = $self->hub->current_workspace->name;
    if ( defined $ws_name and $ws_name ne $this_name ) {
        die "Tried to operate on workspace '$ws_name' with an indexer created "
            . "for workspace '$this_name'.\n";
    }
    $ws_name = $this_name unless defined $ws_name;
    _debug("Asserted right workspace: '$this_name' eq '$ws_name'");
}

##################
# Page Handling
##################

# Load up the page and add its content to the index.
sub index_page {
    my ( $self, $page_uri ) = @_;
    $self->_init_indexer();
    my $page = $self->_load_page($page_uri) || return;
    $self->_add_page_doc($page);
    $self->_finish();
}

# Remove the page from the index.
sub delete_page {
    my ( $self, $page_uri ) = @_;
    $self->_init_indexer();
    $self->_delete_doc_by_key($page_uri);
    $self->_finish();
}

# Create a new Document object and set it's fields.  Then delete the document
# from the index using 'key', which should be unique, and then add the
# document to the index.  The 'key' is just the page id.
sub _add_page_doc {
    my ( $self, $page ) = @_;
    my $doc = $self->_create_new_document();
    $self->_set_fields(
        $doc,
        key   => $page->id,
        text  => $page->content,
        title => $page->title,
        tag  => $self->_get_page_tags($page),
    );
    $self->_add_document($doc);
}

# Get all the tags/categories for a page (sans recent changes) as one string.
sub _get_page_tags {
    my ( $self, $page ) = @_;
    my @tags = grep { !/\brecent changes\b/i } @{ $page->metadata->Category };
    _debug( "Retrieved page tags: " . scalar(@tags) . " tags" );
    return join( " :: ", @tags );
}

########################
# Attachment Handling
########################

# Load an attachment and then add it to the index.
sub index_attachment {
    my ( $self, $page_uri, $attachment_id ) = @_;
    $self->_init_indexer();

    my $attachment = Socialtext::Attachment->new(
        hub     => $self->hub,
        id      => $attachment_id,
        page_id => $page_uri,
    )->load;
    _debug("Loaded attachment: page_id=$page_uri attachment_id=$attachment_id");

    $self->_add_attachment_doc($attachment);
    $self->_finish();
}

# Remove an attachment from the index.
sub delete_attachment {
    my ( $self, $page_uri, $attachment_id ) = @_;
    $self->_init_indexer();
    $self->_delete_doc_by_key( $page_uri . ':' . $attachment_id );
    $self->_finish();
}

# Get the attachments content, create a new Document, set the Doc's fields,
# and add the Document to the index.  The key for this document is
# 'page_id:attachment_id'.
sub _add_attachment_doc {
    my ( $self, $attachment ) = @_;
    my $key     = $attachment->page_id . ':' . $attachment->id;
    my $content = $attachment->to_string;
    _debug( "Retrieved attachment content.  Length is " . length $content );
    return unless length $content;
    $self->_truncate( $key, \$content );

    my $doc = $self->_create_new_document();
    $self->_set_fields(
        $doc,
        key  => $key,
        text => $content,
    );

    $self->_add_document($doc);
}

# Make sure the text we index is not bigger than 20 million characters, which
# is about 20 MB.  Unicode might screw us here with its multibyte characters,
# but I'm not too worried about it.
# 
# The 20 MB figure was arrived at by using the maximum post size in
# Socialtext::MasonHandler.
#
# See {link dev-tasks [KinoSearch - Maximum File Size Cap]} for more
# information.
sub _truncate {
    my ( $self, $key, $text_ref ) = @_;
    my $max_size = 20 * ( 1024**2 );
    return if length($$text_ref) <= $max_size;
    my $info = "ws = " . $self->workspace . " key = $key";
    _debug("Truncating text to $max_size characters:  $info");
    $$text_ref = substr( $$text_ref, 0, $max_size );
}

#################
# Miscellaneous 
#################

# Create a new index object.  If a true value is passed in we create the
# index, which means its erased and recreated if it exists and just created if
# it does not exist.
sub _init_indexer {
    my ( $self, $create ) = @_;
    $create ||= not -e $self->index;

    # Erase anything that came before, then create anew.
    $self->indexer(undef);
    $self->speced(undef);

    # Try to create the indexer, retry until we get a lock.
    $self->_make_indexer($create);
    while ( not defined $self->indexer ) {
        _debug("Sleeping $LOCK_WAIT seconds before trying again.");
        sleep $LOCK_WAIT;
        $self->_make_indexer($create);
    }

    my $create_msg = $create ? "true" : "false";
    _debug( "Loaded indexer: index=" . $self->index . " create=$create_msg" );
}

# Create the indexer object, but pay attention to locking .  Just set the
# indexer to undef if we can't get the lock.  Normally KinoSearch just dies,
# which we want to avoid.
sub _make_indexer {
    my ( $self, $create ) = @_;
    _debug("Attempting to create index in " . $self->index . ".  (May fail if we don't get lock).");

    my $indexer = eval {
        KinoSearch::InvIndexer->new(
            invindex => $self->index,
            create   => $create,
            analyzer => $self->analyzer,
        );
    };
    die "$@\n" if $@ and $@ !~ /Couldn't get lock using.*kinosearch/i;
    return $self->indexer($indexer);
}

# Create a new Document.  The index stores "Document" objects, which contain
# key/value pairs called "Fields".  This function specifies the the fields for
# a document and then creates a new one.  The fields can only be specified
# once, so care is taken not to specify more than once.  We have the following
# fields:
#
#   key - The unique id for the doc (see earlier comments for its structure).
#   title - The title of a page, or empty for an attachment.
#   tag - The categories for a page, or empty for an attachment.
#   text - The body of a page, or the content of an attachment.
#
# See below for the properities of the fields (e.g. not all fields are stored
# or tokenized).  See L<KinoSearch::InvIndexer> for more info on what the
# properites mean.
sub _create_new_document {
    my $self = shift;
    unless ( $self->speced ) {
        $self->indexer->spec_field( name => 'key', analyzed => 0 );
        $self->indexer->spec_field( name => 'title', stored => 0, boost => 4 );
        $self->indexer->spec_field( name => 'tag', stored => 0, boost => 2);
        $self->indexer->spec_field( name => 'text', stored => 0 );
        $self->speced(1);
        _debug("Specified Document fields.");
    }
    _debug("Creating new document object.");
    return $self->indexer->new_doc();
}

# A set of key/value pairs (i.e. fields) are passed in and set on the given
# document.  Logging is done along the way as well.
sub _set_fields {
    my ( $self, $doc, %args ) = @_;
    for my $name ( sort keys %args ) {
        $doc->set_value( $name => $args{$name} );
        _debug( "Field '$name': length=" . length( $args{$name} ) );
        _debug( "Field '$name': snippet=" . substr $args{$name}, 0, 100 );
    }
}

# Add a document to the index.  We try to delete a previous document with the
# same key first, which is a no-op if the document doesn't exist.  Then we add
# the new document that was passed in.  A delete followed by an add is how
# updates are done.
sub _add_document {
    my ( $self, $doc ) = @_;
    my $key = $doc->get_value('key');
    $self->_delete_doc_by_key( $key );
    _debug("Adding document to index: $key");
    $self->indexer->add_doc($doc);
    _debug("Done adding document: $key");
}

# Delete a document which has the given key.
sub _delete_doc_by_key {
    my ( $self, $key ) = @_;
    my $term = KinoSearch::Index::Term->new( key => $key );
    $self->indexer->delete_docs_by_term($term);
    _debug("Deleted document with key: $key.");
}

# Given a page_id, retrieve the corresponding Page object.
sub _load_page {
    my ( $self, $page_id ) = @_;
    _debug("Loading $page_id");
    my $page = $self->hub->pages->new_page($page_id);
    if ( not defined $page ) {
        _debug("Could not load page $page_id");
    }
    elsif ( $page->deleted ) {
        _debug("Page $page_id is deleted, skipping.");
        undef $page;
    }
    _debug("Finished loading $page_id");
    return $page;
}

# Finish creating the index.  This invalidates the indexer object, optionally
# compacts the index on disk, and spews useful debugging information.
sub _finish {
    my ( $self, @args ) = @_;
    _debug("Preparing to finalize index.");
    $self->indexer->finish(@args);
    $self->indexer(undef);
    _debug("Done finalizing index.");
}

# Send a debugging message to syslog.
sub _debug {
    my $msg = shift || "(no message)";
    $msg = __PACKAGE__ . ": $msg";
    st_log->debug($msg);
}

1;
__END__

=pod

=head1 NAME

Socialtext::Search::KinoSearch::Indexer

=cut

=head1 SEE

L<Socialtext::Search::Indexer> for the interface definition.

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

