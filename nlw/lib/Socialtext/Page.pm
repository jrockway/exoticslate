# @COPYRIGHT@
package Socialtext::Page;

=head1 NAME

Socialtext::Page - Base class for NLW pages

=cut

use strict;
use warnings;

use base 'Socialtext::Base';
use base 'Socialtext::Page::Base';
use Socialtext::AppConfig;
use Socialtext::ChangeEvent;
use Socialtext::Encode;
use Socialtext::File;
use Socialtext::Formatter::Parser;
use Socialtext::Formatter::Viewer;
use Socialtext::Formatter::AbsoluteLinkDictionary;
use Socialtext::Log qw( st_log );
use Socialtext::Paths;
use Socialtext::PageMeta;
use Socialtext::Search::AbstractFactory;
use Socialtext::Timer;
use Socialtext::EmailSender::Factory;
use Socialtext::l10n qw(loc system_locale);
use Socialtext::WikiText::Parser;
use Socialtext::WikiText::Emitter::SearchSnippets;
use Socialtext::String;
use Socialtext::Events;
use Socialtext::SQL qw/:exec :txn get_dbh/;
use Socialtext::SQL::Builder qw/sql_insert_many/;

use Carp ();
use Class::Field qw( field const );
use Cwd ();
use DateTime::Format::Strptime;
use Email::Valid;
use File::Path;
use Readonly;
use Text::Autoformat;
use Socialtext::Validate qw(validate :types SCALAR ARRAYREF BOOLEAN POSITIVE_INT_TYPE USER_TYPE);

Readonly my $SYSTEM_EMAIL_ADDRESS       => 'noreply@socialtext.com';
Readonly my $IS_RECENTLY_MODIFIED_LIMIT => 60 * 60; # one hour
Readonly my $WIKITEXT_TYPE              => 'text/x.socialtext-wiki';
Readonly my $HTML_TYPE                  => 'text/html';

field 'id';
sub class_id { 'page' }
field full_uri =>
      -init => '$self->hub->current_workspace->uri . Socialtext::AppConfig->script_name . "?" . $self->uri';
field database_directory => -init =>
    'Socialtext::Paths::page_data_directory( $self->hub->current_workspace->name )';

sub _MAX_PAGE_ID_LENGTH () {
    return 255;
}

=head1 METHODS

=head2 new( %args )

Initializes a page object.  Automatically generates metadata.

=cut

sub new {
    my $class = shift;
    my %p = @_;

    return if $p{id} && length $p{id} > _MAX_PAGE_ID_LENGTH;

    my $self = $class->SUPER::new(%p);
    $self->metadata($self->new_metadata($self->id));
    return $self;
}

sub new_metadata {
    my $self = shift;
    Socialtext::PageMeta->new(hub => $self->hub, id => $self->id);
}

sub name_to_id {
    my $self = shift;
    my $id = shift;
    $id = '' if not defined $id;
    $id =~ s/[^\p{Letter}\p{Number}\p{ConnectorPunctuation}\pM]+/_/g;
    $id =~ s/_+/_/g;
    $id =~ s/^_(?=.)//;
    $id =~ s/(?<=.)_$//;
    $id =~ s/^0$/_/;
    $id = lc($id);
    $self->uri_escape($id);
}

sub name {
    my $self = shift;
    $self->{name} = shift if @_;
    if ( !defined( $self->{name} ) ) {
        $self->{name} = $self->uri_unescape($self->id);
    }
    return $self->{name};
}

=head2 $page->revision_count()

Return the count of revisions that a given page has.

=cut

sub revision_count {
    my $self = shift;
    return scalar $self->all_revision_ids();
}

sub creator {
    my $self = shift;
    return $self->original_revision->last_edited_by;
}

=head2 create( %args )

Creates a page based on the arguments passed in.  If a I<date> arg is
passed, the date is forced.

=cut

sub create {
    my $self = shift;
    my %args = validate(
        @_,
        {
            title      => SCALAR_TYPE,
            content    => SCALAR_TYPE,
            date       => { can => [qw(strftime)], default => undef },
            categories => { type => ARRAYREF, default => [] },
            creator    => USER_TYPE,
        }
    );

    # FIXME: it's possible for this call to return undef and
    # we dont' trap it.
    my $page = $self->hub->pages->new_from_name($args{title});
    $page->content($args{content});
    $page->metadata->Subject($args{title});
    $page->metadata->Category($args{categories});
    $page->metadata->update( user => $args{creator} );

    # hard_set_date does its own store
    if ($args{date}) {
        $page->hard_set_date( $args{date}, $args{creator} );
    }
    else {
        $page->store( user => $args{creator} );
    }

    return $page;
}

=head2 update_from_remote( %args )

Update or create a page with reasonable defaults for some options.
This consolidates replicated code found elsewhere.

The only required arg is 'content' containing the new content of
the page.

=cut

# REVIEW: not sure of the correct spec handling for this
# as much of it is optional. The call to update() does
# verification.

sub update_from_remote {
    my $self = shift;
    my %p = @_;

    my $content     = $self->utf8_decode($p{content});
    my $revision_id = $self->utf8_decode($p{revision_id});
    my $revision    = $self->utf8_decode($p{revision});
    my $subject     = $self->utf8_decode($p{subject});
    my $tags        = $p{tags};

    if ($tags) {
        $tags = [ map { $self->utf8_decode($_) } @$tags ];
    }
    else {
        $tags = $self->metadata->Category;    # preserve categories
    }

    my $user = $self->hub->current_user;

    unless ($self->hub->checker->check_permission('admin_workspace')) {
        delete $p{date};
        delete $p{from};
    }

    # We've already check for permission to do this
    if ( $p{from} ) {
        $user = Socialtext::User->new( email_address => $p{from} );
        $user ||= Socialtext::User->create(
            email_address => $p{from},
            username      => $p{from}
        );
    }
    die "A valid user is required to update a page\n" unless $user;

    $revision_id  ||= $self->revision_id;
    $revision     ||= $self->metadata->Revision || 0;
    $subject      ||= $self->title,

    $self->load;

    if ( $self->revision_id ne $revision_id ) {
        Socialtext::Events->Record({
            event_class => 'page',
            action => 'edit_contention',
            page => $self,
        });

        die "Contention: page has been updated since retrieved\n";
    }

    # REVIEW: cateories/tag naming mismatch, using tag in this
    # method because it is close to the exterior
    $self->update(
        original_page_id => $self->id,
        content          => $content,
        revision         => $revision,
        subject          => $subject,
        categories       => $tags,
        user             => $user,
        $p{date} ? ( date => $p{date} ) : (),
    );

    Socialtext::Events->Record({
        event_class => 'page',
        action => 'edit_save',
        page => $self,
    });
}

=head2 update( %args )

Update or create the page. That is: edit a new or existing page
to replace it's content and metadata. This method is to centralize
various places where this has been done in the past.

=cut
{
    Readonly my $spec => {
        content          => { type => SCALAR,         default => '' },
        original_page_id => SCALAR_TYPE,
        revision         => { type => SCALAR,         regex   => qr/^\d+$/ },
        categories       => { type => ARRAYREF,       default => [] },
        subject          => SCALAR_TYPE,
        user             => USER_TYPE,
        date             => { can  => [qw(strftime)], default => undef },
    };
    sub update {
        my $self = shift;
        my %args = validate( @_, $spec );
        # XXX validate these args

        # explicitly set both id and name to predictable things _now_
        $self->id(Socialtext::Page->name_to_id($args{subject}));
        $self->name($args{subject});

        my $revision
            = $self->id eq $args{original_page_id} ? $args{revision} : 0;

        my $metadata = $self->metadata;
        $metadata->Subject($args{subject});
        $metadata->Revision($revision);
        $metadata->Received(undef);
        $metadata->MessageID('');
        $metadata->loaded(1);
        foreach (@{$args{categories}}) {
            $metadata->add_category($_);
        }

        $self->content($args{content});

        $metadata->update( user => $args{user} );
        # hard_set_date does its own store
        if ($args{date}) {
            $self->hard_set_date( $args{date}, $args{user} );
        }
        else {
            $self->store( user => $args{user} );
        }
    }
}

=head2 $page->hash_representation()

Gets an anonymous hash representing a page. Useful for turning
into JSON objects. Merges pieces of metadata that live on 
L<Socialtext::Page> and L<Socialtext::PageMeta>. This suggests
that perhaps PageMeta is either incomplete or redundant.

The elements of the hash are:

=over 4

=item name

The title of the page

=item uri

The (short) uri of the page

=item page_id

The id of the page

=item page_uri

The fully qualified uri of the page, as presented in the primary
web-based UI

=item tags

A list of the tags which this page has

=item last_editor

The email address of the user that last edited the page

=item last_edit_time

String representation of the date the page was last modified

=item modified_time

Time in seconds since the Unix Epoch the page was last modified

=item revision_id

The identifier for the current revision of this page

=item revision_count

The total count of revisions for this page

=item workspace_name

The name of the workspace where this page lives.

=back

=cut
sub hash_representation {
    my $self = shift;

    # The name, uri, and full_uri are totally botched for pages which never
    # existed.  For pages that never existed the various methods do "smart"
    # things and return values we don't want.  We can't just change the
    # original methods b/c they're part of the bedrock of our app and would
    # have far reaching changes, so we do it here.
    my ( $name, $uri, $page_uri );
    if ( $self->exists ) {
        $name     = $self->metadata->Subject;
        $uri      = $self->uri;
        $page_uri = $self->full_uri;
    }
    else {
        $name     = $self->name;
        $uri      = $self->id;
        $page_uri = $self->hub->current_workspace->uri
            . Socialtext::AppConfig->script_name . "?"
            . $self->id;
    }

    my $from = $self->metadata->From;
    my $user = Socialtext::User->new(email_address => $from);
    my $masked_email = $user
        ? $user->masked_email_address(
            user => $self->hub->current_user,
            workspace => $self->hub->current_workspace,
        ) : $from;

    return +{
        name     => $name,
        uri      => $uri,
        page_id  => $self->id,

        # REVIEW: This URI may eventually prove to be the wrong one
        page_uri       => $page_uri,
        tags           => $self->metadata->Category,
        last_editor    => $masked_email,
        last_edit_time => $self->metadata->Date,
        modified_time  => $self->modified_time,
        revision_id    => $self->revision_id,
        revision_count => $self->revision_count,
        workspace_name => $self->hub->current_workspace->name,

        type => $self->metadata->Type,
    };
}

=head2 $page->get_headers()

Gets a list of hashes describing the headers present on this 
page. The content of the page is passed through the wikitext
formatter to locate the headers, get their level and text.

The returned hashes contained in the list have two elements:

=over 4

=item text

The text of the header

=item level

The size or value of the header (1-6) representing it's nesting
in a hierarchy of headers

=back

=cut
sub get_headers {
    my $self = shift;
    return $self->get_units(
        'hx' => sub {
            return +{text => $_[0]->get_text, level => $_[0]->level}
        },
    );
}


=head2 $page->get_sections()

Gets a list of hashes describing the headers and sections
present on this page. The content of the page is passed
through the wikitext formatter to locate the headers and
the sections.

The returned hashes contained in the list have one element:

=over 4

=item text

The text of the section. For headers this is the header
text. For sections it is the argument of the section wafl
phrase.

=back

=cut
sub get_sections {
    my $self = shift;
    return $self->get_units(
        'hx' => sub {
            return +{text => $_[0]->get_text};
        },
        'wafl_phrase' => sub {
            return unless $_[0]->method eq 'section';
            return +{text => $_[0]->arguments};
        },
    )
}

=head2 $page->get_units(%matches)

Parse the wikitext of a page to find the units named in matches
and push information about each matched unit onto a list that
is returned as a reference.

%matches is made up of key value pairs. The key is the name of a 
valid L<Socialtext::Formatter::Unit>. The value is a 
subroutine that returns a reference to a hash that may
contain anything. The assumption is that it will contain
information about the unit. See get_headers and get_sections
for examples.

=cut 
sub get_units {
    my $self    = shift;
    my %matches = @_;

    my $parser = Socialtext::Formatter::Parser->new(
        table      => $self->hub->formatter->table,
        wafl_table => $self->hub->formatter->wafl_table
    );
    my $parsed_unit = $parser->text_to_parsed( $self->content );

    my @units;

    {
        no warnings 'once';
        # When we use get_text to unwind the parse tree and give
        # us the content of a unit that contains units, we need to
        # make sure that we get the right stuff as get_text is
        # called recursively. This insures we do.
        local *Socialtext::Formatter::WaflPhrase::get_text = sub {
            my $self = shift;
            return $self->arguments;
        };
        my $sub = sub {
            my $unit         = shift;
            my $formatter_id = $unit->formatter_id;
            if ( $matches{$formatter_id} ) {
                push @units, $matches{$formatter_id}->($unit);
            }
        };
        $self->traverse_page_units($parsed_unit->units, $sub);
    }


    return \@units;
}

=head2 $page->traverse_page_units($units, $sub)

Traverse the parse tree of a page to perform the 
actions described in $sub on each unit. $sub is
passed the current unit.

$units is usually the result of
C<Socialtext::Formatter::text_to_parsed($content)->units>

The upshot of that is that this method expects a 
list of units, not a single unit. This makes it
easy for it to be recursive.

=cut
# REVIEW: This should probably be somewhere other than Socialtext::Page
# but where? Socialtext::Formatter? Socialtext::Formatter::Unit?
sub traverse_page_units {
    my $self  = shift;
    my $units = shift;
    my $sub   = shift;

    foreach my $unit (@$units) {
        if (ref $unit) {
            $sub->($unit);
            if ($unit->units) {
                $self->traverse_page_units($unit->units, $sub);
            }
        }
    }
}

=head2 $page->title( [$str] )

Gets or sets the page title.  If the page title, or I<$str>, is not
defined, title is taken from the subject or page name.

=cut

sub title {
    my $self = shift;
    if ( @_ ) {
        $self->{title} = shift;
    }
    if ( !defined $self->{title} ) {
        $self->{title} = $self->metadata->Subject || $self->hub->cgi->page_name;
    }
    return $self->{title};
}

sub prepend {
    my $self = shift;
    my $new_content = shift;

    if (defined($self->content) && $self->content) {
        $self->content("$new_content\n---\n" . $self->content);
    } else {
        $self->content($new_content);
    }
}

sub append {
    my $self = shift;
    my $new_content = shift;

    if (defined($self->content) && $self->content) {
        $self->content($self->content . "\n---\n$new_content");
    }
    else {
        $self->content($new_content);
    }
}

=head2 $page->uri()

Returns the URI for the page.  It cannot be set manually.

=cut

sub uri {
    my $self = shift;
    return $self->{uri} if defined $self->{uri};
    $self->{uri} = $self->exists
    ? $self->id
    : $self->hub->pages->title_to_uri($self->title);
}

=head2 $page->add_tags( @tags )

Adds the given tags string to the Categories on the page.

=cut
sub add_tags {
    my $self = shift;
    my @tags  = @_;
    return unless @tags;

    if ( $self->hub->checker->check_permission('edit') ) {
        my $meta = $self->metadata;
        foreach my $tag (@tags) {
            $meta->add_category($tag);
        }
        $self->metadata->update( user => $self->hub->current_user );
        $self->store( user => $self->hub->current_user );
        foreach my $tag (@tags) {
            Socialtext::Events->Record({
                event_class => 'page',
                action => 'tag_add',
                page => $self,
                tag_name => $tag,
            });
        }
    }
}

=head2 $page->delete_tag( $tag )

Removes the given tag string from the Categories on the page.

=cut

sub delete_tag {
    my $self = shift;
    my $tag = shift;

    if ( $self->hub->checker->check_permission('edit') ) {
        $self->metadata->delete_category($tag);
        $self->store( user => $self->hub->current_user );
    }
}


=head2 $page->has_tag( $tag )

Determines whether a page has a tag

=cut
sub has_tag {
    my $self = shift;
    my $tag = shift;

    return $self->metadata->has_category($tag);
}


=head2 $page->add_comment( $wikitext )

Adds the given comment to the page.  The current user is noted as the comment
author.

=cut

sub add_comment {
    my $self     = shift;
    my $wikitext = shift;

    my $timer = Socialtext::Timer->new;

    # Clean it up.
    $wikitext =~ s/\s*\z/\n/;

    $self->content( $self->content
            . "\n---\n"
            . $wikitext
            . $self->_comment_attribution );

    $self->metadata->update( user => $self->hub->current_user );
    my $user = $self->hub->current_user;

    $self->store( user => $user );

    my $summary = $self->preview_text($wikitext);
    Socialtext::Events->Record({
        event_class => 'page',
        action => 'comment',
        page => $self,
        summary => $summary,
    });
    return;
}

sub _comment_attribution {
    my $self = shift;

    if (    my $email    = $self->hub->current_user->email_address
        and my $utc_date = $self->metadata->get_date ) {
        return "\n_".loc("contributed by {user: [_1]} on {date: [_2]}", $email, $utc_date)."_\n";
    }

    return '';
}

sub restored {
    return ( defined $_[0]->{_restored} ) ? 1 : 0;
}

sub store {
    my $self = shift;
    my %p = @_;
    Carp::confess('no user given to Socialtext::Page->store')
        unless $p{user};

    # Make sure we have minimal metadata needed to store a page
    $self->metadata->update( user => $p{user} )
        unless $self->metadata->Revision;

    # XXX Why are we accessing _MAX_PAGE_ID_LENGTH, which implies to me
    # a very private piece of data.
    if (Socialtext::Page->_MAX_PAGE_ID_LENGTH < length($self->id)) {
        my $message = loc("Page title is too long after URL encoding");
        Socialtext::Exception::DataValidation->throw( errors => [ $message ] );
    }

    $self->{_restored} = 1 if $self->deleted;

    my $original_categories =
      ref($self)->new(hub => $self->hub, id => $self->id)->metadata->Category;

    my $metadata = $self->{metadata}
      or die "No metadata for content object";
    my $body = $self->content;
    if (length $body) {
        $body =~ s/\r//g;
        $body =~ s/\{now\}/$self->formatted_date/egi;
        $body =~ s/\n*\z/\n/;
        $metadata->Control('');
        $metadata->Summary( $self->preview_text( $body ) );
        $self->content($body);
    }
    else {
        $metadata->Control('Deleted');
    }
    $self->write_file($self->headers, $body);
    $self->_perform_store_actions();
}

sub _perform_store_actions {
    my $self = shift;
    $self->hub->backlinks->update($self);
    Socialtext::ChangeEvent->Record($self);
    $self->update_db_metadata();
}

sub update_db_metadata {
    my $self = shift;

    my $hash = $self->hash_representation;
    my $wksp_id = $self->hub->current_workspace->workspace_id;
    my $pg_id = $hash->{page_id};
    sql_begin_work();

    my $sth = sql_execute(
        'SELECT creator_id, create_time FROM page
            WHERE workspace_id = ? AND page_id = ?',
        $wksp_id, $pg_id,
    );
    my $rows = $sth->fetchall_arrayref();
    my ($creator_id, $create_time);
    if (@$rows) {
        $creator_id = $rows->[0][0];
        $create_time = $rows->[0][1];
    }
    else {
        my $orig_page = $self->original_revision;
        $creator_id = $orig_page->last_edited_by->user_id;
        $create_time = $orig_page->metadata->Date;
    }

    my $exists = sql_singlevalue('SELECT page_id FROM page 
                                  WHERE workspace_id = ? 
                                  AND page_id = ? FOR UPDATE', 
                                 $wksp_id, $pg_id);

    my @args = (
        $hash->{name},
        $self->last_edited_by->user_id, $hash->{last_edit_time},
        $creator_id, $create_time,
        $hash->{revision_id}, $self->metadata->Revision,
        $hash->{revision_count},
        $hash->{type}, $self->deleted ? '1' : '0', $self->metadata->Summary,
        $wksp_id, $pg_id
    );
    my $insert_or_update;
    if ($exists) {
        $insert_or_update = <<'UPDSQL';
            UPDATE page SET
                name = ?,
                last_editor_id = ?, last_edit_time = ?,
                creator_id = ?, create_time = ?,
                current_revision_id = ?, current_revision_num = ?,
                revision_count = ?,
                page_type = ?, deleted = ?, summary = ?
            WHERE
                workspace_id = ? AND page_id = ?
UPDSQL

        # we don't reference the page_tag table, so it's safe to nuke 'em
        sql_execute('DELETE FROM page_tag 
                     WHERE workspace_id = ? AND page_id = ?',
                    $wksp_id, $pg_id);
    }
    else {
        $insert_or_update = <<'INSSQL';
            INSERT INTO page (
                name, 
                last_editor_id, last_edit_time, 
                creator_id, create_time,
                current_revision_id, current_revision_num, 
                revision_count,
                page_type, deleted, summary,
                workspace_id, page_id
            )
            VALUES (
                ?,
                ?, ?::timestamptz,
                ?, ?::timestamptz,
                ?, ?, 
                ?, 
                ?, ?, ?,
                ?, ?
            )
INSSQL
    }
    sql_execute($insert_or_update, @args);

    my $tags = $self->metadata->Category;
    if (@$tags) {
        sql_insert_many( 
            page_tag => [qw/workspace_id page_id tag/],
            [ map { [$wksp_id, $pg_id, $_] } @$tags ],
        );
    }

    sql_commit();
}

sub is_system_page {
    my $self = shift;

    my $from = $self->metadata->From;
    return (
               $from eq $SYSTEM_EMAIL_ADDRESS
            or $from eq Socialtext::User->SystemUser()->email_address()
    );
}

sub content_or_default {
    my $self = shift;
    return $self->is_spreadsheet
        ? ($self->content || loc('Creating a New Spreadsheet...') . '   ')
        : ($self->content || loc('Replace this text with your own.') . '   ');
}

sub content {
    my $self = shift;
    return $self->{content} = shift if @_;
    return $self->{content} if defined $self->{content};
    $self->load_content;
    return $self->{content};
}

=head2 content_as_type(%p)

Return the content of the page as a particular mime type, formatting
as needed. Takes optional arguments:

=over 4

=item type

The mime type of the desired content. Default is text/x.socialtext-wiki

=item link_dictionary

The name of a link_dictionary to use when formatting. Only used when
type is text/html

=item no_cache

If true, don't use the formatter cache when creating HTML output.
This is useful when viewing revisions.

=back

=cut
sub content_as_type {
    my $self = shift;
    my %p    = @_;

    my $type = $p{type} || $WIKITEXT_TYPE;

    my $content;

    if ( $type eq $HTML_TYPE ) {
        return $self->_content_as_html( $p{link_dictionary}, $p{no_cache} );
    }
    elsif ( $type eq $WIKITEXT_TYPE ) {
        return $self->content();
    }
    else {
        Socialtext::Exception->throw("unknown content type");
    }
}

sub _content_as_html {
    my $self            = shift;
    my $link_dictionary = shift;
    my $no_cache        = shift;

    if ( defined $link_dictionary ) {
        my $link_dictionary_name = 'Socialtext::Formatter::'
            . $link_dictionary
            . 'LinkDictionary';
        my $link_dictionary;
        eval {
            eval "require $link_dictionary_name";
            $link_dictionary = $link_dictionary_name->new();
        };
        if ($@) {
            my $message
                = "Unable to create link dictionary $link_dictionary_name: $@";
            Socialtext::Exception->throw($message);
        }
        $self->hub->viewer->link_dictionary($link_dictionary);
    }

    # REVIEW: the args to to_html are to help make caching work
    if ($no_cache) {
        return $self->to_html;
    }
    else {
        return $self->to_html( $self->content, $self );
    }
}

sub doctor_links_with_prefix {
    my $self = shift;
    my $prefix = shift;
    my $new_content = $self->content();
    my $link_class = 'Socialtext::Formatter::FreeLink';
    my $start = $link_class->pattern_start;
    my $end = $link_class->pattern_end;
    $new_content =~ s/{ (link:\s+\S+\s) \[ ([^\]]+) \] }/{$1\{$2}}/xg;
    # $start contains grouping syntax so we must skip $2
    $new_content =~ s/($start)((?!$prefix).+?)($end)/$1$prefix$3$4/g;
    $new_content =~ s/{ (link:\s+\S+\s) { ([^}]+) }}/{$1\[$2]}/xg;
    $self->content($new_content);
}

sub categories_sorted {
    my $self = shift;
    return sort {lc($a) cmp lc($b)} @{$self->metadata->Category};
}

sub html_escaped_categories {
    my $self = shift;
    return map { $self->html_escape($_) } $self->categories_sorted;
}

sub metadata {
    my $self = shift;
    return $self->{metadata} = shift if @_;
    $self->{metadata} ||=
      Socialtext::PageMeta->new(hub => $self->hub, id => $self->id);
    return $self->{metadata} if $self->{metadata}->loaded;
    $self->load_metadata;
    return $self->{metadata};
}

sub last_edited_by {
    my $self = shift;
    return unless $self->id && $self->metadata->From;

    my $email_address = $self->metadata->From;
    # We have some very bogus data on our system, so this is a really
    # horrible hack to fix it.
    unless ( Email::Valid->address($email_address) ) {
        my ($name) = $email_address =~ /([\w-]+)/;
        $name = 'unknown' unless defined $name;
        $email_address = $name . '@example.com';
    }

    my $user = Socialtext::User->new( email_address => $email_address );

    # There are many usernames in pages that were never in the users
    # table.  We need to have all users in the DBMS, so
    # we assume that if they don't exist, they should be created. When
    # we import pages into the DBMS, we'll need to create any
    # non-existent users at the same time, for referential integrity.
    $user ||= Socialtext::User->create(
        username         => $email_address,
        email_address    => $email_address,
    );

    return $user;
}

sub size {
    my $self = shift;
    my $filename = $self->_index_path or return 0;
    return scalar((stat($filename))[7]);
}

sub _index_path {
    my $self = shift;
    my $filename = readlink $self->_get_index_file;
    -f $filename or return;
    return $filename;
}

sub modified_time {
    my $self = shift;
    return $self->{modified_time} if defined $self->{modified_time};
    # REVIEW: Can't this use $self->file_path ?
    my $path = Socialtext::File::catfile(
        Socialtext::Paths::page_data_directory( $self->hub->current_workspace->name ),
        $self->id,
    );
    $self->{modified_time} = (stat($path))[9] || time;
    return $self->{modified_time};
}

=head2 is_recently_modified( [$limit] )

Returns true if the page object was recently modified. With no arguments
the default is 'changed in the last hour'. If an argument is passed, it
is the maximum number of seconds since the last change for that change to
be considered recent.

=cut

sub is_recently_modified {
    my $self = shift;
    my $limit = shift;
    $limit ||= $IS_RECENTLY_MODIFIED_LIMIT;

    return $self->age_in_seconds < $limit;
}

sub age_in_minutes {
    my $self = shift;
    $self->age_in_seconds / 60;
}

sub age_in_seconds {
    my $self = shift;
    return $self->{age_in_seconds} = shift if @_;
    return $self->{age_in_seconds} if defined $self->{age_in_seconds};
    return $self->{age_in_seconds} = (time - $self->modified_time);
}

sub age_in_english {
    my $self = shift;
    my $age = $self->age_in_seconds;
    my $english =
    $age < 60 ? loc('[_1] seconds', $age) :
    $age < 3600 ? loc('[_1] minutes', int($age / 60)) :
    $age < 86400 ? loc('[_1] hours', int($age / 3600)) :
    $age < 604800 ? loc('[_1] days', int($age / 86400)) :
    $age < 2592000 ? loc('[_1] weeks', int($age / 604800)) :
    loc('[_1] months', int($age / 2592000));

    $english =~ s/^(1 .*)s$/$1/;
    return $english;
}

=head2 hard_set_date( $date, $user )

Forces the date for the revision to I<$date> for user I<$user>, and sets the
file's timestamp in the filestamp.

=cut

sub hard_set_date {
    my $self = shift;
    my $date = shift;
    my $user = shift;
    $self->metadata->Date($date->strftime('%Y-%m-%d %H:%M:%S GMT'));
    $self->store( user => $user );
    utime $date->epoch, $date->epoch, $self->file_path;
    $self->{modified_time} = $date->epoch;
}

sub datetime_for_user {
    my $self = shift;
    if (my $date = $self->metadata->Date) {
        return $self->hub->timezone->date_local($date);
    }

    # XXX metadata starts out life as empty string
    return '';
}


# cgi->title guesses the title from query_string, so $self->hub->cgi->title
# is always defined even if it's a bad guess
# REVIEW: refactor to fold this into the above when it's all better -- replace
# title_better with title and perform regression testing to make sure nothing
# is broken
sub title_better {
    my $self = shift;
    if ( !defined( $self->{title} ) ) {
        $self->{title} = $self->metadata->Subject || $self->hub->cgi->page_name;
    }
    return $self->{title};
}

sub all {
    my $self = shift;
    return (
        page_uri => $self->uri,
        page_title => $self->title,
        page_title_uri_escaped => $self->uri_escape($self->title),
        revision_id => $self->revision_id,
    );
}

sub to_html_or_default {
    my $self = shift;
    $self->to_html($self->content_or_default, $self);
}

sub is_spreadsheet { $_[0]->metadata->Type eq 'spreadsheet' }

sub delete {
    my $self = shift;
    my %p = @_;

    my $timer = Socialtext::Timer->new;

    Carp::confess('no user given to Socialtext::Page->delete')
        unless $p{user};

    my $indexer
        = Socialtext::Search::AbstractFactory->GetFactory->create_indexer(
        $self->hub->current_workspace->name );

    foreach my $attachment ( $self->attachments ) {
        $indexer->delete_attachment( $self->uri, $attachment->id );
    }

    $self->load;
    $self->content('');
    $self->metadata->Category([]);
    $self->store( user => $p{user} );

    Socialtext::Events->Record({
        event_class => 'page',
        action => 'delete',
        page => $self,
    });
    return;
}

sub purge {
    my $self = shift;

    # clean up the index first
    my $indexer
        = Socialtext::Search::AbstractFactory->GetFactory->create_indexer(
        $self->hub->current_workspace->name );

    foreach my $attachment ( $self->attachments ) {
        $indexer->delete_attachment( $self->uri, $attachment->id );
    }

    $indexer->delete_page( $self->uri);

    my $page_path = $self->directory_path or die "Page has no directory path";
    -d $page_path or die "$page_path does not exist";
    my $attachment_path = join '/', $self->hub->attachments->plugin_directory, $self->id;
    File::Path::rmtree($attachment_path)
      if -e $attachment_path;
    File::Path::rmtree($page_path);

    my $hash    = $self->hash_representation;
    my $wksp_id = $self->hub->current_workspace->workspace_id;

    sql_begin_work();
    sql_execute('DELETE FROM page WHERE workspace_id = ? and page_id = ?',
        $wksp_id, $hash->{page_id}
    );
    sql_execute('DELETE FROM page_tag WHERE workspace_id = ? and page_id = ?',
        $wksp_id, $hash->{page_id}
    );
    sql_commit();
}

Readonly my $ExcerptLength => 350;
sub preview_text {
    my $self = shift;

    return $self->preview_text_spreadsheet(@_)
        if $self->is_spreadsheet;

    my $content = shift || $self->content;

    # Gigantic pages caused Perl segfaults. Only need the beginning of the
    # content.
    my $max_length = $ExcerptLength * 2;
    if (length($content) > $max_length) {
        $content = substr($content, 0, $max_length);
        $content =~ s/(.*\n).*/$1/s;
    }

    my $excerpt = $self->_to_plain_text( $content );
    $excerpt = substr( $excerpt, 0, $ExcerptLength ) . '...'
        if length $excerpt > $ExcerptLength;
    return Socialtext::String::html_escape($excerpt);
}

sub preview_text_spreadsheet {
    my $self = shift;

    my $content = shift || $self->content;
    $content = $self->_to_spreadsheet_plain_text($content);

    $content = substr( $content, 0, $ExcerptLength ) . '...'
        if length $content > $ExcerptLength;

    return Socialtext::String::html_escape($content);
}

sub _store_preview_text {
    my $self = shift;
    my $preview_text; # Optional; defaults to $self->preview_text -- see below

    return unless my $index_file = $self->_get_index_file;

    my $filename = readlink $index_file;
    if (not -f $filename) {
        warn "$filename is no good for _store_preview_text";
        return;
    }

    my $mtime = $self->modified_time;
    my $data = $self->_get_contents_decoded_as_utf8($filename);
    my $headers = substr($data, 0, index($data, "\n\n") + 1);
    my $old_length = length($headers);
    return if $headers =~ /^Summary:\ +\S/m;
    $headers =~ s/^Summary:.*\n//mg;

    if (@_) {
        # If explicitly specified, use the specified text
        $preview_text = shift;
    }
    else {
        # Otherwise, generate preview based on the newly decoded data
        $preview_text = $self->preview_text(substr($data, $old_length + 1));
    }

    $preview_text = '...' if $preview_text =~ /^\s*$/;
    $preview_text =~ s/\s*\z//;
    return if $preview_text =~ /\n/;
    $headers .= "Summary: $preview_text\n";

    my $body = substr($data, $old_length);
    my $tmp_file = "$filename.tmp";
    Socialtext::File::set_contents_utf8($tmp_file, $headers . $body);
    rename $tmp_file => $filename 
        or warn "rename $tmp_file => $filename failed: $!";

    $self->set_mtime($mtime, $filename);
}


sub _get_contents_decoded_as_utf8 {
    my $self = shift;
    my $file = shift;

    my $data = Socialtext::File::get_contents($file);
    my $headers = substr($data, 0, index($data, "\n\n") + 1);
    my $old_length = length($headers);

    # If the page has an encoding, decode it as such.
    if ($headers =~ /^Encoding:\ +utf8\n/m) {
        # The common case is UTF-8, so just decode it.
        return Encode::decode_utf8($data);
    }
    elsif ($headers =~ s/^Encoding:\ +(\S+)\n/Encoding: utf8\n/m) {
        # Decode the page according to its declared encoding.
        my $encoding = $1;
        my $body = substr($data, $old_length);
        return Encode::decode($encoding, $headers . $body);
    }
    else {
        # Force conversion from legacy pages; first try UTF-8, then ISO-8859-1.
        local $@;
        my $data_from_utf8 = eval {
            Encode::decode_utf8($data, Encode::FB_CROAK());
        };
        if ($@) {
            # It was not UTF-8 -- fallback to ISO-8859-1.
            return "Encoding: utf8\n" . Encode::decode('iso-8859-1', $data);
        }
        else {
            # It was UTF-8, so simply prepend the correct header.
            return "Encoding: utf8\n" . $data_from_utf8;
        }
    }
}

sub _to_plain_text {
    my $self    = shift;
    my $content = shift || $self->content;

    if ($self->is_spreadsheet) {
        return $self->_to_spreadsheet_plain_text( $content );
    }

    # The WikiText::Parser doesn't yet handle really large chunks,
    # so we should chunk this up ourself.
    my $chunk_start = 0;
    my $chunk_size  = 100 * 1024;
    my $plain_text  = '';
    while (1) {
        my $chunk = substr( $content, $chunk_start, $chunk_size );
        last unless length $chunk;
        $chunk_start += length $chunk;

        $plain_text
            .= $self->_to_socialtext_wikitext_parser_plain_text($chunk);
    }
    return $plain_text;
}

sub _to_socialtext_formatter_parser_plain_text {
    my $self    = shift;
    my $content = shift;

    my $parser = Socialtext::Formatter::Parser->new(
        table => $self->hub->formatter->table,
        wafl_table => $self->hub->formatter->wafl_table,
    );
    my $units = $parser->text_to_parsed($content);
    return Socialtext::Formatter::Viewer->to_text( $units );
}

sub _to_socialtext_wikitext_parser_plain_text {
    my $self    = shift;
    my $content = shift;

    my $parser = Socialtext::WikiText::Parser->new(
       receiver => Socialtext::WikiText::Emitter::SearchSnippets->new,
    );

    my $return = "";
    eval { $return = $parser->parse($content) };
    warn $@ if $@;
    return $return;
}

sub _to_spreadsheet_plain_text {
    my $self    = shift;
    my $content = shift;

    my $html_offset = index($content, "\n__SPREADSHEET_HTML__\n") + 21;
    return '' unless length($content) > $html_offset;
    $content = substr( $content, $html_offset );
    $content = substr(
        $content,
        0,
        index($content, "\n__SPREADSHEET_VALUES__\n")
    );

    $content =~ s/<td[^>]*><\/td>//sg;
    $content =~ s/<tr[^>]*><\/tr>//sg;
    $content =~ s/<td.*?>/ \| /sg;
    $content .= ' |';

    $content =~ s/<.*?>//sg;
    $content =~ s/&nbsp;/ /g;
    $content =~ s/\s+/ /g;
    $content =~ s/\|\s+(?=\|)//g;

    # Since we are starting with HTML (for spreadsheets) things will
    # already be escaped.
    return Socialtext::String::html_unescape($content);
}

# REVIEW: We should consider throwing exceptions here rather than return codes.
sub duplicate {
    my $self = shift;
    my $dest_ws = shift;
    my $target_page_title = shift;
    my $keep_categories = shift;
    my $keep_attachments = shift;
    my $clobber = shift || '';
    my $is_rename = shift || 0;

    my $dest_main = Socialtext->new;
    $dest_main->load_hub(
        current_workspace => $dest_ws,
        current_user      => $self->hub->current_user,
    );
    my $dest_hub = $dest_main->hub;
    $dest_hub->registry->load;

    my $target_page = $dest_hub->pages->new_from_name($target_page_title);

    # XXX need exception handling of better kind
    # Don't clobber an existing page if we aren't clobbering
    if ($target_page->metadata->Revision
            and $target_page->active
            and ($clobber ne $target_page_title)) {
        return 0;
    }

    my $target_page_id = ref($self)->name_to_id($target_page_title);
    $target_page->content($self->content);
    $target_page->metadata->Subject($target_page_title);
    $target_page->metadata->Category($self->metadata->Category)
      if $keep_categories;
    $target_page->metadata->update( user => $dest_hub->current_user );

    $target_page->metadata->Type($self->metadata->Type);

    if ($keep_attachments) {
        my @attachments = $self->attachments();
        for my $source_attachment (@attachments) {
            my $target_attachment = $dest_hub->attachments->new_attachment(
                    id => $source_attachment->id,
                    page_id => $target_page_id,
                    filename => $source_attachment->filename,
                );

            my $target_directory = $dest_hub->attachments->plugin_directory;
            $target_attachment->copy($source_attachment, $target_attachment, $target_directory);
            $target_attachment->store( user => $dest_hub->current_user,
                                       dir  => $target_directory );
        }
    }

    $target_page->store( user => $dest_hub->current_user );

    Socialtext::Events->Record({
        event_class => 'page',
        action => ($is_rename ? 'rename' : 'duplicate'),
        page => $self,
        target_workspace => $dest_hub->current_workspace,
        target_page => $target_page,
    });

    Socialtext::Events->Record({
        event_class => 'page',
        action => 'edit_save',
        page => $target_page,
    });

    return 1; # success
}

# REVIEW: We should consider throwing exceptions here rather than return codes.
sub rename {
    my $self = shift;
    my $new_page_title = shift;
    my $keep_categories = shift;
    my $keep_attachments = shift;
    my $clobber = shift || '';

    # If the new title of the page has the same page-id as the old then just
    # change the title, and don't mess with the other bits.
    my $new_id = $self->name_to_id($new_page_title);
    if ( $self->id eq $new_id ) {
        $self->title($new_page_title);
        $self->metadata->Subject($new_page_title);
        $self->metadata->update( user => $self->hub->current_user );
        $self->store( user => $self->hub->current_user );
        return 1;
    }

    my $return = $self->duplicate(
        $self->hub->current_workspace,
        $new_page_title,
        $keep_categories,
        $keep_attachments,
        $clobber,
        'rename'
    );

    if ($return) {
        my $localized_str = loc("Page renamed to [_1]", $new_page_title);
        $localized_str =~ s/^Page\ renamed\ to\ /Page\ renamed\ to\ \[/;
        $localized_str =~ s/$/\]/;
        $self->content($localized_str);
        $self->metadata->Type("wiki");
        $self->store( user => $self->hub->current_user );
    }

    return $return;
}

sub send_as_email {
    my $self = shift;
    # REVIEW: Candidate for Socialtext::Validate
    my $ADDRESS_LIST_TYPE = {
        type => SCALAR | ARRAYREF, default => undef,
        callbacks => { 'has addresses' => sub { ! ref $_[0] or @{$_[0]} > 0 } }
    };
    my %p = validate(@_, {
        from => SCALAR_TYPE,
        to => $ADDRESS_LIST_TYPE,
        cc => $ADDRESS_LIST_TYPE,
        subject => { type => SCALAR, default => $self->title },
        body_intro => { type => SCALAR, default => '' },
        include_attachments => { type => BOOLEAN, default => 0 },
    });

    die "Must provide at least one address via the to or cc parameters"
      unless $p{to} || $p{cc};

    if ( $p{cc} and not $p{to} ) {
        $p{to} = $p{cc};
        delete $p{cc},
    }

    my $body_content;

    if ($p{include_attachments}) {
        my $prev_formatter = $self->hub->formatter;
        my $formatter = Socialtext::Pages::Formatter->new(hub => $self->hub);
        $self->hub->formatter($formatter);
        $body_content = $self->to_absolute_html( $p{body_intro} . $self->content );
        $self->hub->formatter($prev_formatter);
    }
    else {
        # If we don't have attachments, don't link to nonexistent "cid:" hrefs. {bz: 1418}
        $body_content = $self->to_absolute_html( $p{body_intro} . $self->content );
    }

    my $html_body = $self->hub->template->render(
        'page_as_email.html',
        title        => $p{subject},
        body_content => $body_content,
    );

    my $text_body = Text::Autoformat::autoformat(
        $p{body_intro} . $self->content, {
            all    => 1,
            # This won't actually work properly until the next version
            # of Text::Autoformat, as 1.13 has a bug.
            ignore =>
                 qr/# this regex is copied from Text::Autoformat ($ignore_indented)
                   (?:^[^\S\n].*(\n[^\S\n].*)*$)
                   |
                   # this matches table rows
                   (?:^\s*\|(?:(?:[^\|]*\|)+\n)+$)
                  /x,
        },
    );

    my %email = (
        to        => $p{to},
        subject   => $p{subject},
        from      => $p{from},
        text_body => $text_body,
        html_body => $html_body,
    );
    $email{cc} = $p{cc} if defined $p{cc};
    $email{attachments} =
        [ map { $_->full_path() } $self->attachments ]
            if $p{include_attachments};

    my $locale = system_locale();
    my $email_sender = Socialtext::EmailSender::Factory->create($locale);
    $email_sender->send(%email);
}

sub is_in_category {
    my $self = shift;
    my $category = shift;

    grep {$_ eq $category} @{$self->metadata->Category};
}

sub deleted {
    my $self = shift;
    $self->metadata->Control eq 'Deleted';
}

sub load_revision {
    my $self = shift;
    my $revision_id = shift;

    $self->revision_id($revision_id);
    return $self->load;
}

sub load {
    my $self        = shift;
    my $page_string = shift;

    my $metadata = $self->{metadata}
        or die "No metadata object in content object";

    my $headers;
    if ($page_string) {
        $headers = $self->_read_page_string($page_string);
    }
    else {
        $headers = $self->_read_page_file();
    }
    $metadata->from_hash($self->parse_headers($headers));
    return $self;
}

sub load_content {
    my $self = shift;
    my $content = $self->_read_page_file(content => 1);
    $self->content($content);
    return $self;
}

sub load_metadata {
    my $self = shift;
    my $metadata = $self->{metadata}
      or die "No metadata object in content object";
    my $headers = $self->_read_page_file();
    $metadata->from_hash($self->parse_headers($headers));
    $metadata->{Type} ||= 'wiki';
    return $self;
}

sub parse_headers {
    my $self = shift;
    my $headers = shift;
    my $metadata = {};
    for (split /\n/, $headers) {
        next unless /^(\w\S*):\s*(.*)$/;
        my ($attribute, $value) = ($1, $2);
        if (defined $metadata->{$attribute}) {
            $metadata->{$attribute} = [$metadata->{$attribute}]
              unless ref $metadata->{$attribute};
            push @{$metadata->{$attribute}}, $value;
        }
        else {
            $metadata->{$attribute} = $value;
        }
    }
    return $metadata;
}

# This method is used only by testing tool.
sub _read_page_string {
    my $self = shift;
    my $string = shift;

    die "Not a string ($string)" if ref($string);
    my ($headers, $content) = split "\n\n", $string, 2;
    $self->content($content);
    return $headers;
}

sub _read_page_file {
    my $self   = shift;
    my %p      = @_;
    my $return_content = $p{content};

    my $revision_id = $self->assert_revision_id;
    return $self->_read_empty unless $revision_id;
    my $filename = $self->current_revision_file;
    return read_and_decode_file($filename, $return_content);
}

sub read_and_decode_file {
    my $filename       = shift;
    my $return_content = shift;
    die "No such file $filename" unless -f $filename;
    die "File path contains '..', which is not allowed."
        if $filename =~ /\.\./;

    # Note: avoid using '<:raw' here, it sucks for performance
    open(my $fh, '<', $filename)
        or die "Can't open $filename: $!";
    binmode($fh); # will Encode bytes to characters later

    my $buffer;
    {
        # slurp in the header only:
        local $/ = "\n\n";
        $buffer = <$fh>;
    }

    if ($return_content) { 
        # slurp in the rest of the file:
        local $/ = undef;
        $buffer = <$fh> || '';
    }

    $buffer = Socialtext::Encode::noisy_decode(
            input => $buffer,
            blame => $filename
    );

    $buffer =~ s/\015\012/\n/g;
    $buffer =~ s/\015/\n/g;
    return $buffer;
}

sub _read_empty {
    my $self = shift;
    my $text = '';
    $self->utf8_decode($text);
}

=head2 revision_id( $id )

If $id is present, sets the revision_id of this object. This is the
way to retrieve an older revision.

If $id is not present, returns the revision_id of the page object.

Debates on what a revision_id is left as an exercise for the 
reader. See also L<Socialtext::PageMeta> and its Revision field.

=cut
sub revision_id {
    my $self = shift;
    if (@_) {
        $self->{revision_id} = shift;
        return $self->{revision_id};
    }
    return $self->assert_revision_id;
}

=head2 restore_revision( $id )

Loads and stores the revision specified by I<$id>.

=cut

{
    Readonly my $spec => {
        revision_id => POSITIVE_INT_TYPE,
        user        => USER_TYPE,
    };
    sub restore_revision {
        my $self = shift;
        my %p = validate( @_, $spec );
        my $id = shift;

        $self->revision_id( $p{revision_id} );
        $self->load;
        $self->store( user => $p{user} );
    }
}

sub _get_index_file {
    my $self      = shift;
    my $dir       = $self->directory_path;
    my $filename  = "$dir/index.txt";

    return $filename if -f $filename;
    return '' unless my @revisions = $self->all_revision_ids;

    # This is adding some fault-tolerance to the system. If the index.txt file
    # doesn not exist, we're gonna re-create it rather than throw an error.
    my $revision_file = $self->revision_file( pop @revisions ); 
    Socialtext::File::safe_symlink($revision_file => $filename);

    return $filename;
}

# XXX split this into a getter and setter to more
# accurately measure how often it is called as a
# setter. In a fake-request run of 50, this is called 1100
# times, which is, uh, high. When disk is loaded, it eats
# a lot of real time.
sub assert_revision_id {
    my $self = shift;
    my $revision_id = $self->{revision_id};
    return $revision_id if $revision_id;
    return '' unless my $index_file = $self->_get_index_file;

    $revision_id = readlink $index_file;
    $revision_id =~ s/(?:.*\/)?(.*)\.txt$/$1/
      or die "$revision_id is bad file name";
    $self->revision_id($revision_id);
}

sub headers {
    my $self = shift;
    my $metadata = $self->metadata;
    my $hash = $metadata->to_hash;
    my @keys = $metadata->key_order;
    my $headers = '';
    for my $key (@keys) {
        my $attribute = $key;
        $key =~ s/^([A-Z][a-z]+)([A-Z].*)$/$1-$2/;
        my $value = $metadata->$attribute;
        next unless defined $value;
        unless (ref $value) {
            $value =~ tr/\r\n/  /s;
            $value = [$value];
        }
        $headers .= "$key: $_\n" for grep {defined $_ and length $_} @$value;
    }
    return $headers;
}

sub write_file {
    my $self = shift;
    my ($headers, $body) = @_;
    my $id = $self->id
      or die "No id for content object";
    my $revision_file = $self->revision_file( $self->new_revision_id );
    my $page_path = join '/', Socialtext::Paths::page_data_directory( $self->hub->current_workspace->name ), $id;
    Socialtext::File::ensure_directory($page_path, 0, 0755);
    Socialtext::File::set_contents_utf8($revision_file, join "\n", $headers, $body);

    my $index_path = join '/', $page_path, 'index.txt';
    Socialtext::File::safe_symlink($revision_file => $index_path);
}

sub current_revision_file {
    my $self = shift;
    $self->revision_file($self->assert_revision_id);
}

sub revision_file {
    my $self = shift;
    my $revision_id = shift;
    my $filename = join '/', 
        ( $self->database_directory, $self->id, $revision_id . '.txt' );
    return $filename;
}

sub new_revision_id {
    my $self = shift;
    my ($sec,$min,$hour,$mday,$mon,$year) = gmtime(time);
    my $id = sprintf(
        "%4d%02d%02d%02d%02d%02d",
        $year + 1900, $mon + 1, $mday, $hour, $min, $sec
    );
    # REVIEW: This is the minimum change to avoid revision id collisions.
    # It's not the best solution, but there are so many options and enough
    # indecision that the wrong way sticks around in pursuit of the 
    # right way. So here's something adequate that does not cascade 
    # changes in the rest of the code.
    unless (-f $self->revision_file($id)) {
        $self->revision_id($id);
        return $id;
    }
    sleep 1;
    return $self->new_revision_id();

}

sub formatted_date {
    # formats the current date/time in iso8601 format
    my $now = DateTime->now();
    my $fmt = DateTime::Format::Strptime->new( pattern => '%F %T %Z' );
    my $res = $fmt->format_datetime( $now );
    $res =~ s/UTC$/GMT/;    # refer to it as "GMT", not "UTC"
    return $res;
}

sub active {
    my $self = shift;
    return $self->exists && not $self->deleted;
}

sub is_bad_page_title {
    my ( $class, $title ) = @_;
    $title = defined($title) ? $title : "";

    # No empty page titles.
    return 1 if $title =~ /^\s*$/;

    # Can't have a page named "Untitled Page"
    my $untitled_page = $class->name_to_id( loc("Untitled Page") );
    return 1 if $class->name_to_id($title) eq $untitled_page;

    return 0;
}

sub summary { $_[0]->metadata->{Summary} }

# This is called by Socialtext::Query::Plugin::push_result
sub to_result {
    my $self = shift;
    my $metadata = $self->metadata;

    my $result = {};
    $result->{$_} = $metadata->$_
      for qw(From Date Subject Revision Summary Type);
    $result->{DateLocal} = $self->datetime_for_user;
    $result->{revision_count} = $self->revision_count;
    $result->{page_uri} = $self->uri;
    $result->{page_id} = $self->id;
    $result->{is_spreadsheet} = $self->is_spreadsheet;
    my $user = $self->last_edited_by;
    $result->{username} = $user ? $user->username : '';
    if (not $result->{Summary}) {
        my $text = $self->preview_text;
        $self->_store_preview_text($text);
        $result->{Summary} = $text;
    }
    return $result;
}

1;
