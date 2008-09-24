# @COPYRIGHT@
package Socialtext::Attachment;
use strict;
use base 'Socialtext::Base';
use Class::Field qw( field );
use Email::Valid;
use MIME::Types;
use Socialtext::Encode;
use Socialtext::File::Stringify;

my $MAX_WIDTH  = 600;
my $MAX_HEIGHT = 600;

my $encoding_charset_map = {
    'euc-jp' => 'EUC-JP',
    'shiftjis' => 'Shift_JIS',
    'iso-2022-jp' => 'ISO-2022-JP',
    'utf8' => 'UTF-8',
    'cp932' => 'CP932',
    'iso-8859-1' => 'ISO-8859-1',
};

sub class_id { 'attachment' }
field 'id';
field 'page_id';
field 'filename';
field 'db_filename';
field 'loaded';
field 'Control' => '';
field 'From';
field 'Subject';
field 'DB_Filename';
field 'Date';
field 'Received';
field 'Content_MD5';
field 'Content_Length';
field 'Content_type';

sub new {
    my $self = shift;
    $self = $self->SUPER::new(@_);
    $self->id($self->new_id)
      unless $self->id;
    $self->page_id($self->hub->pages->current->id)
      unless $self->page_id;
    if (my $filename = $self->filename) {
        $filename = $self->clean_filename($filename);
        $self->filename($filename);
        $self->db_filename($self->uri_escape($filename));
    }
    return $self;
}

sub clean_filename {
    my $self = shift;
    my $filename = shift;

    $filename = Socialtext::Encode::ensure_is_utf8(
        $filename
    );
    $filename =~ s/[\/\\]+$//;
    $filename =~ s/^.*[\/\\]//;
    # why would we do  ... => ~~.  ?
    $filename =~ s/(\.+)\./'~' x length($1) . '.'/ge;
    return $filename;
}

my $x = 0;
sub new_id {
    my $self = shift;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
    $year += 1900;
    my $id = sprintf('%4d%02d%02d%02d%02d%02d-%d-%d', 
        $year, $mon+1, $mday, $hour, $min, $sec, $x++, $$
    );
    return $id;
}

sub load {
    my $self = shift;
    return $self if $self->loaded;

    my $path = $self->_content_file;

    for ( Socialtext::File::get_contents_utf8($path) ) {
        next unless /^(\w\S*):\s*(.*)$/;
        my $value = $2;
        ( my $key = $1 ) =~ s/-/_/g;
        next unless $self->can($key);
        $self->$key($value);
    }

    {
        # This might be undef here, and lots of tests use -w which will cause
        # confusing warnings from inside URI::Escape.  Harmless to remove this
        # localized var, but it reduces some noise.
        local $^W = 0; 
        $self->filename( $self->Subject );
        $self->db_filename( $self->DB_Filename
                || $self->uri_escape( $self->Subject ) );
    }

    $self->loaded(1);
    return $self;
}

sub _content_file {
    my $self = shift;

    return Socialtext::File::catfile(
        $self->hub->attachments->plugin_directory,
        $self->page_id,
        $self->id . '.txt',
    );
}

sub save {
    my $self = shift;
    my $tmp_file = shift;
    my $id = $self->id;
    my $db_filename = $self->db_filename;
    my $page_id = $self->page_id;

    my $attachdir = $self->hub->attachments->plugin_directory;
    my $file_path = "$attachdir/$page_id/$id";
    $self->assert_dirpath($file_path);
    my $dest = "$file_path/$db_filename";
    File::Copy::copy($tmp_file, $dest)
        or die "Couldn't copy from $tmp_file to $dest : $!";
    chmod(0755, $dest)
        or die "Couldn't set permissions on $dest : $!";
}

sub extract {
    my $self = shift;

    my $filename = join '/',
        $self->hub->attachments->plugin_directory,
        $self->page_id,
        $self->id,
        $self->db_filename;

    my $tmpdir = File::Temp::tempdir( CLEANUP => 1 );

    # Socialtext::ArchiveExtractor uses the extension to figure out how to extract the
    # archive, so that must be preserved here.
    my $basename = File::Basename::basename($filename);
    my $tmparchive = "$tmpdir/$basename";

    open my $tmpfh, '>', $tmparchive
        or die "Couldn't open $tmparchive for writing: $!";
    File::Copy::copy($filename, $tmpfh)
        or die "Cannot save $basename to $tmparchive: $!";
    close $tmpfh;

    my @files = Socialtext::ArchiveExtractor->extract( archive => $tmparchive );
    # If Socialtext::ArchiveExtractor couldn't extract anything we'll
    # attach the archive file itself.
    @files = $tmparchive unless @files;

    my @attachments;
    for my $file (@files) {
        open my $fh, '<', $file or die "Cannot read $file: $!";

        my $attachment = Socialtext::Attachment->new(
            hub      => $self->hub,
            filename => $file,
            fh       => $fh,
            creator  => $self->hub->current_user,
            page_id  => $self->page_id,
        );
        $attachment->save($fh);
        my $creator = $self->hub->current_user;
        $attachment->store(user => $creator);
        $attachment->inline( $self->page_id, $creator );
    }

    return @attachments;
}


sub attachdir {
    my $self = shift;
    return $self->{attachdir} if defined $self->{attachdir};

    my $attachdir = $self->hub->attachments->plugin_directory;
    my $page_id = $self->page_id;
    my $id = $self->id;
    $attachdir = "$attachdir/$page_id/$id";
}

sub dimensions {
    my ($self, $size) = @_;
    $size ||= '';
    return if $size eq 'scaled' and $self->hub->current_workspace->no_max_image_size;
    return unless $size;
    return [0, 0] if $size eq 'scaled';
    return [100, 0] if $size eq 'small';
    return [300, 0] if $size eq 'medium';
    return [600, 0] if $size eq 'large';
    return [$1 || 0, $2 || 0] if $size =~ /^(\d+)(?:x(\d+))?$/;
}

sub image_path {
    my $self = shift;
    my $size = shift;

    my $dimensions = $self->dimensions($size);

    my $paths = $self->{image_path};

    my $attachdir = $self->attachdir;
    my $db_filename = $self->db_filename;

    my $original = $paths->{original} ||= 
        join '/', $self->attachdir, $db_filename;

    # Return original if the we have nothing to resize
    return $original unless defined $dimensions and -f $original;

    my $size_dir = join '/', $attachdir, $size;
    my $path = $paths->{$size} ||= join '/', $size_dir, $db_filename;
    mkdir $size_dir unless -d $size_dir;

    return $path if -f $path;

    # This can fail in a variety of ways, mostly related to
    # the file not being what it says it is.
    eval {
        File::Copy::copy($original, $path)
            or die "Could not copy $original to $path: $!\n";
        Socialtext::Image::resize(
            new_width  => $dimensions->[0],
            new_height => $dimensions->[1],
            max_height => $MAX_HEIGHT,
            max_width  => $MAX_WIDTH,
            filename   => $path,
        );
    };
    # Return original on error
    if ($@) {
        warn "Reverting to original: $@"; 
        unlink $path;
        return $original;
    }

    return $path;
}

sub is_image {
    my $self = shift;
    return $self->{is_image} if defined $self->{is_image};
    return $self->{is_image} = $self->mime_type =~ /image/;
}

# XXX - this should be used elsewhere in this package
sub full_path {
    my $self = shift;
    return $self->image_path(@_) if $self->is_image;
    return $self->{full_path} if defined $self->{full_path};
    $self->{full_path} = join '/', $self->attachdir, $self->db_filename;
    return $self->{full_path};
}

sub copy {
    my $self = shift;
    my $source = shift;
    my $target = shift;
    my $target_directory = shift;

    my $sourcefile = $source->db_filename;
    my $sourcedir = $source->hub->attachments->plugin_directory;
    my $source_page_id = $source->page_id;
    my $source_id = $source->id;
    my $sourcepath = "$sourcedir/$source_page_id/$source_id";
    $self->assert_dirpath($sourcepath);

    my $targetfile = $target->db_filename;

    my $target_page_id = $target->page_id; my $target_id = $target->id;
    my $targetpath = "$target_directory/$target_page_id/$target_id";

    $self->assert_dirpath($targetpath);

    File::Copy::copy("$sourcepath/$sourcefile", "$targetpath")
        or die "Can't copy $sourcepath/$sourcefile into $targetpath: $!";

    chmod(0755, $targetpath);
}

sub store {
    my $self = shift;
    my %p = @_;

    Carp::confess('no user given to Socialtext::Attachment->store')
        unless $p{user} && eval { $p{user}->can('email_address') };

    my $target_dir = $p{dir};
    my $id = $self->id;
    my $filename = $self->filename;
    my $db_filename = $self->db_filename;
    my $page_id = $self->page_id;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
    $year += 1900;
    my $prt_date = sprintf("%4d-%02d-%02d %02d:%02d:%02d GMT",
                        $year, $mon+1, $mday, $hour, $min, $sec
                       );
    my $attachdir = $target_dir || $self->hub->attachments->plugin_directory;
    my $file_path = "$attachdir/$page_id/$id";
    $self->assert_dirpath($file_path);

    my $md5;
    open IN, '<', "$file_path/$db_filename"
      or die "Can't open $file_path/$db_filename for MD5 checksum: $!";
    binmode IN;
    $md5 = Digest::MD5->new->addfile(*IN)->b64digest;
    close IN;

    #need test for command line invocation
    my $remote_addr='';
    if  ($ENV{REMOTE_ADDR}) {
        $remote_addr = $ENV{REMOTE_ADDR};
    }

    my $from = $p{user}->email_address;

    my $filesize = -s "$file_path/$db_filename";
    open my $out, '>', "$file_path.txt"
        or die "Can't open output file: $!";
    binmode($out, ':utf8');
    print $out "Control: Deleted\n" if $self->deleted;
    print $out "Content-type: ", $self->Content_type, "\n"
        if $self->Content_type;
    print $out $self->utf8_decode(<<"QUOTEDTEXT");
From: $from
Subject: $filename
DB_Filename: $db_filename
Date: $prt_date
Received: from $remote_addr
Content-MD5: $md5==
Content-Length: $filesize

QUOTEDTEXT
    close $out;

    # XXX: refactor into MetaDataObject with all metadata,
    # XXX: including Subject, Received, Control
    $self->filename($filename);
    $self->db_filename($db_filename);
    $self->Date($prt_date);
    $self->Content_Length($filesize);
    $self->Content_MD5("$md5==");
    $self->From($from);

    $self->hub->attachments->index->add($self) unless $self->deleted;
    Socialtext::ChangeEvent->Record($self);
}

sub page {
    my $self = shift;
    $self->hub->pages->new_page($self->page_id);
}

# XXX - a copy of Socialtext::Page->last_edited_by()
sub uploaded_by {
    my $self = shift;
    return unless $self->From;

    my $email_address = $self->From;
    # We have some very bogus data on our system, so this is a really
    # horrible hack to fix it.
    unless ( Email::Valid->address($email_address) ) {
        my ($name) = $email_address =~ /([\w-]+)/;
        $email_address = $name . '@example.com';
    }

    my $user = Socialtext::User->new( email_address => $email_address );

    # XXX - there are many usernames for pages that were never in
    # users.db or any htpasswd.db file. We need to have all users in
    # the DBMS, so we assume that if they don't exist, they should be
    # created. When we import pages into the DBMS, we'll need to
    # create any non-existent users at the same time, for referential
    # integrity.
    $user ||= Socialtext::User->create(
        username      => $email_address,
        email_address => $email_address,
    );

    return $user;
}

sub short_name {
    my $self = shift;
    my $name = $self->Subject;
    $name =~ s/ /_/g;
    return $name
      unless $name =~ /^(.{16}).{2,}(\..*)/;
    return "$1..$2";
}

sub content {
    my $self = shift;
    Socialtext::File::get_contents($self->full_path);
}

sub deleted {
    my $self = shift;
    return $self->{deleted} = shift if @_;
    return $self->{deleted} if defined $self->{deleted};
    $self->load;
    $self->{deleted} = $self->Control eq 'Deleted' ? 1 : 0;
}

sub delete {
    my $self = shift;
    my %p = @_;
    Carp::confess('no user given to Socialtext::Attachment->delete')
        unless $p{user};

    $self->load;
    $self->deleted(1);
    $self->store(%p);
    $self->hub->attachments->index->delete($self);
}

sub exists {
    return -f $_[0]->_content_file;
}

sub serialize {
    my $self = shift;
    return {
        filename => $self->filename,
        date     => $self->Date,
        length   => $self->Content_Length,
        md5      => $self->Content_MD5,
        from     => $self->From,
        page_id  => $self->page_id,
        id       => $self->id,
    };
}

sub inline {
    my $self = shift;
    my $page_id = shift;
    my $user = shift;

    my $page = $self->hub->pages->new_page($page_id);
    $page->metadata->update( user => $user );

    my $content = $page->content;
    $content = $self->image_or_file_wafl . $content;
    $page->content($content);
    $page->store( user => $user );
}

sub mime_type {
    my $self = shift;

    my $type = $self->Content_type;

    if ($type) {
        return $type;
    }
    my $type_object = MIME::Types->new->mimeTypeOf( $self->filename );
    return $type_object ? $type_object->type : 'application/binary';
}

sub charset {
    my $self = shift;
    my $locale = shift;

    my $encoding = Socialtext::File->get_guess_encoding( $locale, $self->full_path );
    my $charset = $encoding_charset_map->{$encoding};
    if (! defined $charset ) {
        $charset = 'UTF-8';
    }

    return $charset;
}

sub should_popup {
    my $self = shift;
    my @easy_going_types = (
        qr|^text/|, # especially text/html
        qr|^image/|,
        qr|^video/|,
        # ...any others?   ...any exceptions?
    );
    return not grep { $self->mime_type =~ $_ } @easy_going_types;
}

#XXX use MIME::Types?
sub image_or_file_wafl {
    my $self = shift;
    my $filename = $self->utf8_decode($self->filename);
    $filename =~ /\.(bmp|gif|jpg|jpeg|png)$/i
      ? "{image: $filename}" . "\n\n"
      : "{file: $filename}" . "\n\n";
}

sub assert_dirpath {
    my $self = shift;
    my $path = shift;

    File::Path::mkpath($path)
        unless -d $path;
}

sub preview_text {
    my $self = shift;
    my $content = shift || $self->content;

    my $ExcerptLength = 350;

    my $excerpt = $self->to_string;
    $excerpt = substr( $excerpt, 0, $ExcerptLength ) . '...'
        if length $excerpt > $ExcerptLength;
    return $excerpt;
}

sub to_string {
    my $self = shift;
    return Socialtext::File::Stringify->to_string( $self->full_path,
        $self->mime_type );
}

sub purge {
    my $self = shift;
    my $page = shift;

    # clean up the index first
    my $indexer
        = Socialtext::Search::AbstractFactory->GetFactory->create_indexer(
        $self->hub->current_workspace->name );

    $indexer->delete_attachment( $page->uri, $self->id );

    $self->delete(user => $self->hub->current_user());

    my $attachment_path = join '/', $self->hub->attachments->plugin_directory, $page->id, $self->id;
    my $attachment_txt = $attachment_path . ".txt";
    
    if ( -e $attachment_path ) {
        unlink($attachment_txt);
        File::Path::rmtree($attachment_path);
    }
}

1;
