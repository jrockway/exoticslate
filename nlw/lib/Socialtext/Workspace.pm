# @COPYRIGHT@
package Socialtext::Workspace;

use strict;
use warnings;
no warnings 'redefine';

our $VERSION = '0.01';

use Socialtext::Exceptions
    qw( rethrow_exception param_error data_validation_error );
use Socialtext::Validate qw(
    validate validate_pos SCALAR_TYPE BOOLEAN_TYPE ARRAYREF_TYPE
    HANDLE_TYPE URI_TYPE USER_TYPE ROLE_TYPE PERMISSION_TYPE FILE_TYPE
    DIR_TYPE UNDEF_TYPE
);

use Class::Field 'field';
use Cwd ();
use DateTime;
use DateTime::Format::Pg;
use Digest::MD5;
use Email::Address;
use File::chdir;
use File::Copy ();
use File::Find ();
use File::Path ();
use File::Temp ();
use IPC::Run qw/run/;
use List::MoreUtils ();
use MIME::Types;
use Socialtext;
use Socialtext::AppConfig;
use Socialtext::EmailAlias;
use Socialtext::File;
use Socialtext::File::Copy::Recursive qw(dircopy);
use Socialtext::Helpers;
use Socialtext::Image;
use Socialtext::l10n qw(loc system_locale);
use Socialtext::Log qw( st_log );
use Socialtext::Paths;
use Socialtext::SQL qw(
    sql_execute
    sql_commit sql_rollback sql_begin_work
    sql_singlevalue
);
use Socialtext::String;
use Readonly;
use Socialtext::Account;
use Socialtext::Permission qw( ST_EMAIL_IN_PERM ST_READ_PERM );
use Socialtext::Role;
use Socialtext::URI;
use Socialtext::MultiCursor;
use Socialtext::User;
use Socialtext::UserWorkspaceRole;
use Socialtext::WorkspaceBreadcrumb;
use Socialtext::Page;
use Socialtext::Workspace::Permissions;
use Socialtext::Timer;
use Socialtext::Pluggable::Adapter;
use URI;
use YAML;
use Encode qw(decode_utf8);

# workspace schema fields
# FIXME: so god damned many. something is really wrong here

Readonly our @COLUMNS => (
    'workspace_id',
    'name',
    'title',
    'logo_uri',
    'homepage_weblog',
    'email_addresses_are_hidden',
    'unmasked_email_domain',
    'prefers_incoming_html_email',
    'incoming_email_placement',
    'allows_html_wafl',
    'email_notify_is_enabled',
    'sort_weblogs_by_create',
    'external_links_open_new_window',
    'basic_search_only',
    'enable_unplugged',
    'skin_name',
    'custom_title_label',
    'header_logo_link_uri',
    'show_welcome_message_below_logo',
    'show_title_below_logo',
    'comment_form_note_top',
    'comment_form_note_bottom',
    'comment_form_window_height',
    'page_title_prefix',
    'email_notification_from_address',
    'email_weblog_dot_address',
    'comment_by_email',
    'homepage_is_dashboard',
    'creation_datetime',
    'account_id',
    'created_by_user_id',
    'restrict_invitation_to_search',
    'invitation_filter',
    'invitation_template',
    'customjs_uri',
    'customjs_name',
    'no_max_image_size',
    'cascade_css',
    'uploaded_skin',
    'allows_skin_upload',
);

# Hash for quick lookup of columns
my %COLUMNS = map { $_ => 1 } @COLUMNS;

foreach my $column (@COLUMNS) {
    field $column;
}

# XXX: This is here to support the non-plugin method of checking whether
# socialcalc is enabled or not.
sub enable_spreadsheet {
    my ($self, $option) = @_;
    return $self->is_plugin_enabled('socialcalc');
}

# Special case the "help" workspace.  Since existing Wikitext (and rarely used
# code) still refer to the "help" workspace, we need to capture that here and
# call help_workspace(), which should automagically load up the right
# workspace.
sub new {
    my ( $class, %args ) = @_;
    if ( $args{name} and $args{name} eq 'help' ) {
        delete $args{name};
        return $class->help_workspace(%args);
    }

    return $class->_new(%args);
}

# This is in _new() b/c of now migration 13 works.  Please read that migration
# before you move this code.
sub _new {
    my ( $class, %args ) = @_;
    my $sth;
    if (my $name = $args{name}) {
        $sth = sql_execute(
            qq{SELECT * FROM "Workspace" WHERE LOWER(name) = ?}, lc($name),
        );
    }
    elsif (my $id = $args{workspace_id}) {
        $sth = sql_execute(
            qq{SELECT * FROM "Workspace" WHERE workspace_id = ?}, $id,
        );
    }
    else {
        return;
    }

    # Sure there's a better way to make use of the row we're getting back.
    my $row = $sth->fetchrow_hashref();
    return $class->_new_from_hash_ref($row);
}

sub _new_from_hash_ref {
    my ( $class, $row ) = @_;
    return $row unless $row;
    return Socialtext::NoWorkspace->new if $row->{workspace_id} == 0;

    # Make sure that workspaces with UTF-8 titles display properly.
    # Keep an eye out for other places that we may need to do this.
    $row->{title} = decode_utf8( $row->{title} );

    return bless $row, $class;
}

sub create {
    my $class = shift;
    my %p = @_;
    my $timer = Socialtext::Timer->new;

    my $skip_pages       = delete $p{skip_default_pages};
    my $clone_pages_from = delete $p{clone_pages_from};

    my $self;
    eval {
        sql_begin_work();

        $class->_validate_and_clean_data(\%p);
        my $keys = join(',', sort keys %p);
        my $vals = join(',', map {'?'} keys %p);

        my $sql = <<EOSQL;
INSERT INTO "Workspace" ( workspace_id, $keys )
    VALUES (nextval('"Workspace___workspace_id"'), $vals)
EOSQL
        sql_execute($sql, map { $p{$_} } sort keys %p);

        $self = $class->new( name => $p{name} );

        my $creator = $self->creator;
        unless ( $creator->is_system_created ) {
            $self->add_user(
                user => $creator,
                role => Socialtext::Role->WorkspaceAdmin(),
            );
        }

        $self->permissions->set( set_name => 'member-only' );
        sql_commit();
    };

    if ( my $e = $@ ) {
        sql_rollback();
        rethrow_exception($e);
    }

    $self->_make_fs_paths();

    if ( $clone_pages_from ) {
        $self->_clone_workspace_pages( $clone_pages_from );
    }
    else {
        $self->_copy_default_pages
            unless $skip_pages;
    }

    $self->_update_aliases_file();

    my $msg = 'CREATE,WORKSPACE,workspace:' . $self->name  
              . '(' . $self->workspace_id . '),'
              . '[' . $timer->elapsed . ']';
    st_log()->info($msg);

    return $self;
}

# Load the right help workspace for the current system locale.
sub help_workspace {
    my ( $class, %args ) = @_;
    my $ws;
    delete $args{name};
    for my $locale ( system_locale(), "en" ) {
        $ws ||= $class->new( name => "help-$locale", %args );
    }
    return $ws;
}

sub _clone_workspace_pages {
    my $self    = shift;
    my $ws_name = shift;

    my $ws = Socialtext::Workspace->new( name => $ws_name ) || return;
    my $clone_hub = $self->_hub_for_workspace( $ws_name );
    my @pages = $clone_hub->pages->all();

    my ( $main, $hub ) = $self->_main_and_hub();
    my $homepage = $hub->pages->new_from_name( $ws->title )->id;

    $self->_add_workspace_pages( $homepage, @pages );
}

sub _copy_default_pages {
    my $self = shift;
    my ( $main, $hub ) = $self->_main_and_hub();

    # Load up the help workspace, and a corresponding hub.
    my $help     = (Socialtext::Workspace->help_workspace() || return)->name || return;
    my $help_hub = $self->_hub_for_workspace( $help );

    # Get all the default pages from the help workspace
    my @pages = $help_hub->category->get_pages_for_category( loc("Welcome") );
    push @pages, $help_hub->category->get_pages_for_category( loc("Top Page") );

    my $homepage_id = ( system_locale() eq 'ja' )
        ? '%E3%83%88%E3%83%83%E3%83%97%E3%83%9A%E3%83%BC%E3%82%B8'
        : 'top_page';

    $self->_add_workspace_pages( $homepage_id,  @pages );
}

sub _hub_for_workspace {
    my $self      = shift;
    my $ws_name   = shift;

    my $ws = Socialtext::Workspace->new( name => $ws_name );
    my $hub = Socialtext->new->load_hub(
        current_workspace => $ws,
        current_user      => Socialtext::User->SystemUser,
    );

    $hub->registry->load;

    return $hub;
}

# Top Page is special.  We need to name the page after the current
# workspace, not "Top Page", and we need to add the current workspace
# title to the page content (there's some TT2 in the wikitext).
sub _add_workspace_pages {
    my $self        = shift;
    my $top_page_id = shift;
    my @pages       = @_;

    my ( $main, $hub ) = $self->_main_and_hub();

    # Duplicate the pages
    for my $page (@pages) {
        my $title = $page->title;

        if ( $page->id eq $top_page_id ) {
            $title = $self->title;
            my $content = $page->content;
            my $content_formatted = $hub->template->process(
                \$content,
                workspace_title => $self->title
            );
            $page->content($content_formatted);
            $page->metadata->Category([]);
        } else {
            $page->delete_tag("Top Page");
        }

        $page->duplicate(
            $self,        # Destination workspace
            $title,
            "keep tags",
            "keep attachments",
            $title,      # Ok to overwrite existing pages named $title
        );
    }
}

sub _main_and_hub {
    my $self = shift;

    my $main = Socialtext->new;
    my $hub = $main->load_hub(
        current_workspace => $self,
        current_user      => Socialtext::User->SystemUser(),
    );
    $hub->registry->load;

    return ( $main, $hub );
}

sub _make_fs_paths {
    my $self = shift;

    for my $dir ( grep { ! -d } $self->_data_dir_paths() ) {
        File::Path::mkpath( $dir, 0, 0755 );
    }
}

sub _data_dir_paths {
    my $self = shift;
    my $name = shift || $self->name;

    return (
        Socialtext::Paths::page_data_directory( $name ),
        Socialtext::Paths::plugin_directory( $name ),
        Socialtext::Paths::user_directory( $name ),
    );
}

sub _update_aliases_file {
    my $self = shift;

    Socialtext::EmailAlias::create_alias( $self->name );
}

sub update {
    my $self = shift;
    my %args = @_;

    delete $self->{skin_info}{$_} for keys %args;

    my $old_title = $self->title();

    $self->_update(@_);

    if ( $self->title() ne $old_title ) {
        my ( $main, $hub ) = $self->_main_and_hub();

        my $page = $hub->pages->new_from_name($old_title);

        return unless $page->active();

        $page->rename(
            $self->title(),
            'keep categories',
            'keep attachments',

            # forces the rename to replace an existing page
            $self->title(),
        );
    }
}

sub _update {
    my ( $self, %p ) = @_;

    $self->_validate_and_clean_data(\%p);

    my ( @updates, @bindings );
    while (my ($column, $value) = each %p) {
        push @updates, "$column=?";
        push @bindings, $value;
    }

    if (@updates) {
        my $set_clause = join ', ', @updates;
        sql_execute(
            'UPDATE "Workspace"'
            . " SET $set_clause WHERE workspace_id=?",
            @bindings, $self->workspace_id);

        while (my ($column, $value) = each %p) {
            $self->$column($value);
        }
    }

    return $self;
}

sub skin_name {
    my $self = shift;
    my $value = shift;

    if (defined $value) {
        $self->{skin_name} = $value;
        return $value;
    }
    return $self->{skin_name} || '';
}

# turn a workspace into a hash suitable for JSON and such things.
sub to_hash {
    my $self = shift;
    my $hash = {
        map { $_ => $self->$_ } @COLUMNS
    };
    $hash->{account_name}
        = Socialtext::Account->new(account_id => $hash->{account_id})->name;

    return $hash;
}

sub delete {
    my $self = shift;
    my $timer = Socialtext::Timer->new;

    for my $dir ( $self->_data_dir_paths() ) {
        File::Path::rmtree($dir);
    }

    Socialtext::EmailAlias::delete_alias( $self->name );

    sql_execute( 'DELETE FROM "Workspace" WHERE workspace_id=?',
        $self->workspace_id );

    st_log()
        ->info( 'DELETE,WORKSPACE,workspace:'
            . $self->name . '('
            . $self->workspace_id
            . '),[' . $timer->elapsed . ']' );
}

my %ReservedNames = map { $_ => 1 } qw(
    account
    administrate
    administrator
    atom
    attachment
    attachments
    category
    control
    console
    data
    feed
    id
    nlw
    noauth
    page
    recent-changes
    rss
    search
    soap
    static
    st-archive
    superuser
    test-selenium
    workspace
    wsdl
    user
);

sub _validate_and_clean_data {
    my $self = shift;
    my $p = shift;

    my $is_create = ref $self ? 0 : 1;

    # XXX - this is really gross - I want to force people to use the
    # set_logo_* API to set the logo, but then set_logo_* eventually
    # calls this method.
    if ( $p->{logo_uri} and ( $is_create or not $self->{allow_logo_uri_update_HACK} ) ) {
        my $meth = $is_create ? 'create()' : 'update()';
        die 'Cannot set logo_uri via ' . $meth . '.'
            . ' Use set_logo_from_file() or set_logo_from_uri().';
    }

    if ( defined $p->{name} and not $is_create and not $self->{allow_rename_HACK} ) {
        die "Cannot rename workspace via update(). Use rename() instead.";
    }

    my @errors;
    {
        $p->{name} = Socialtext::String::trim( $p->{name} )
            if defined $p->{name};

        if ( ( exists $p->{name} or $is_create )
             and not
             ( defined $p->{name} and length $p->{name} ) ) {
            push @errors, loc("Workspace name is a required field.");
        }
    }

    {
        $p->{title} = Socialtext::String::trim( $p->{title} )
            if defined $p->{title};

        if ( ( exists $p->{title} or $is_create )
             and not
             ( defined $p->{title} and length $p->{title} ) ) {
            push @errors, loc("Workspace title is a required field.");
        }
    }

    if ( defined $p->{name} ) {
        $p->{name} = lc $p->{name};

        Socialtext::Workspace->NameIsValid( name => $p->{name},
                                            errors => \@errors );

        if ( Socialtext::EmailAlias::find_alias( $p->{name} ) ) {
            push @errors, loc("The workspace name you chose, [_1], is already in use as an email alias.", $p->{name});
        }

        if ( Socialtext::Workspace->new( name => $p->{name} ) ) {
            push @errors, loc("The workspace name you chose, [_1], is already in use by another workspace.", $p->{name});
        }
    }

    if ( defined $p->{title} ) {
        Socialtext::Workspace->TitleIsValid( title => $p->{title},
                                            errors => \@errors );
    }

    if ( $p->{incoming_email_placement}
         and $p->{incoming_email_placement} !~ /^(?:top|bottom|replace)$/ ) {
        push @errors, loc('Incoming email placement must be one of top, bottom, or replace.');
    }

    if ($p->{skin_name}) {
        my $skin = Socialtext::Skin->new(name => $p->{skin_name});
        unless ($skin->exists) {
            push @errors, loc("The skin you specified, [_1], does not exist.",
                $p->{skin_name});
        }
    }

    if ( $is_create and not $p->{account_id} ) {
        push @errors, loc("An account must be specified for all new workspaces.");
    }

    if ($p->{account_id}) {
        my $account = Socialtext::Account->new(account_id => $p->{account_id});
        push @errors,
            loc("The account_id you specified, [_1], does not exist.",
                $p->{account_id}) unless $account;
    }

    data_validation_error errors => \@errors if @errors;

    if ( $p->{logo_uri} ) {
        $p->{logo_uri} = URI->new( $p->{logo_uri} )->canonical . '';
    }

    if ($is_create) {
        $p->{created_by_user_id} ||= Socialtext::User->SystemUser()->user_id();
    }

    # Remove keys that aren't columns, or are undef
    for my $k (keys %$p) {
        delete $p->{$k} unless $COLUMNS{$k};
        delete $p->{$k} unless defined $p->{$k};
    }
}


sub TitleIsValid {
    my $class = shift;

    my %p = Params::Validate::validate( @_, {
        title    => SCALAR_TYPE,
        errors  => ARRAYREF_TYPE( default => [] ),
    } );

    my $title    = $p{title};
    my $errors  = $p{errors};

    unless (    defined $title
        and ( length $title >= 2 )
        and ( length $title <= 64 )
        and ( $title !~ /^-/ ) ) {
        push @{$errors},
            loc(
            'Workspace title must be between 2 and 64 characters long and may not begin with a -.'
            );
    }

    if ( defined $title
         and ( length Socialtext::Page->name_to_id($title) > Socialtext::Page->_MAX_PAGE_ID_LENGTH() )
       ) {
        push @{$errors}, loc('Workspace title is too long after URL encoding');
    }

    return @{$errors} > 0 ? 0 : 1;
}


sub NameIsValid {
    my $class = shift;

    # The validation spec is specified here, instead of outside
    # the sub, so that any default 'errors' arrayref will be different on
    # each call. If the spec is defined outside this scope, then the same
    # arrayref will be used for every call with a defaulted 'errors'
    # parameter, mistakenly preserving the error list between calls.
    #
    my %p = Params::Validate::validate( @_, {
        name    => SCALAR_TYPE,
        errors  => ARRAYREF_TYPE( default => [] ),
    } );

    my $name    = $p{name};
    my $errors  = $p{errors};

    if ( $name !~ /^[a-z0-9_\-]{3,30}$/ ) {
        push @{$errors},
            loc('Workspace name must be between 3 and 30 characters long, and must contain only upper- or lower-case letters, numbers, underscores, and dashes.');
    }

    if ( $name =~ /^-/ ) {
        push @{$errors},
            loc('Workspace name may not begin with -.');
    }

    if ( $ReservedNames{$name} || ($name =~ /^st_/i) ) {
        push @{$errors},
            loc("'[_1]' is a reserved workspace name and cannot be used.", $name);
    }

    return @{$errors} > 0 ? 0 : 1;
}


{
    Readonly my $spec => { name => SCALAR_TYPE };
    sub rename {
        my $self = shift;
        my %p    = validate( @_, $spec );
        my $timer = Socialtext::Timer->new;

        my $old_name  = $self->name();
        my @old_paths = $self->_data_dir_paths();

        local $self->{allow_rename_HACK} = 1;
        $self->update( name => $p{name} );

        my @new_paths = $self->_data_dir_paths();

        for ( my $x = 0; $x < @old_paths; $x++ ) {
            CORE::rename $old_paths[$x] => $new_paths[$x]
                or die "Cannot rename $old_paths[$x] => $new_paths[$x]: $!";
        }

        my @index_links;
        File::Find::find(
            sub {
                push( @index_links, $File::Find::name )
                    if -l && $_ eq 'index.txt';
            },
            Socialtext::Paths::page_data_directory( $self->name )
        );

        for my $link (@index_links) {
            my $filename = File::Basename::basename( readlink $link );

            unlink $link or die "Cannot unlink $link: $!";

            my $new
                = Socialtext::File::catfile( File::Basename::dirname($link),
                $filename );
            symlink $new => $link
                or die "Cannot symlink $new to $link: $!";
        }

        Socialtext::EmailAlias::delete_alias($old_name);
        $self->_update_aliases_file();

        st_log()
            ->info( 'RENAME,WORKSPACE,old_workspace:'
                . $old_name . '(' . $self->workspace_id . '),'
                . 'new_workspace:' . $p{name} . '('
                . $self->workspace_id
                . '),[' . $timer->elapsed . ']' );
    }
}

sub real { 1 }

sub uri {
    my $self = shift;

    return Socialtext::URI::uri(
        path   => $self->name . '/',
    );
}

sub email_in_address {
    my $self = shift;

    return $self->name . '@' . Socialtext::AppConfig->email_hostname;
}

sub formatted_email_notification_from_address {
    my $self = shift;

    return Email::Address->new( $self->title(),
        $self->email_notification_from_address() )->format();
}

sub logo_uri_or_default {
    my $self = shift;
    my ( $main, $hub ) = $self->_main_and_hub();

    return $self->logo_uri if $self->logo_uri;

    return Socialtext::Skin->new(name => 's2')->skin_uri(
        qw(images st logo socialtext-logo-152x26.gif)
    );
}

sub logo_filename {
    my $self = shift;

    my $uri = $self->logo_uri;
    return unless $uri and $uri =~ m{^/logos/};

    my ($filename) = $uri =~ m{([^/]+)$};
    my $file = Socialtext::File::catfile( $self->_logo_path, $filename );

    return unless -f $file;
    return $file;
}

{
    Readonly my %ValidTypes => (
        'image/jpeg' => 'jpg',
        'image/gif'  => 'gif',
        'image/png'  => 'png',
    );

    sub set_logo_from_file {
        my $self = shift;
        my %p = @_;

        my $mime_type = MIME::Types->new()->mimeTypeOf( $p{filename} );
        unless ( $mime_type and $ValidTypes{$mime_type} ) {
            data_validation_error errors => [ loc("Logo file must be a gif, jpeg, or png file.") ];
        }

        my $new_file = $self->_new_logo_filename( $ValidTypes{$mime_type} );
        # 0775 is intentional on the theory that the directory
        # owner:group will be something like root:www-data
        File::Path::mkpath( File::Basename::dirname($new_file), 0, 0775 );

        # This can fail in a variety of ways, mostly related to
        # the file not being what it says it is.
        File::Copy::copy($p{filename}, $new_file)
            or die "Could not copy $p{filename} to $new_file $!\n";
        eval {
            Socialtext::Image::resize(
                max_width  => 200,
                max_height => 60,
                filename   => $new_file,
            );
        };
        if ($@) {
            data_validation_error errors =>
                [loc('Unable to process logo file. Is it an image?')];
        }

        my $old_logo_file = $self->logo_filename();

        my $logo_uri = join '/', '/logos', $self->name, File::Basename::basename($new_file);

        local $self->{allow_logo_uri_update_HACK} = 1;
        $self->update( logo_uri => $logo_uri  );

        if ( $old_logo_file and $old_logo_file ne $self->logo_filename() ) {
            unlink $old_logo_file or die "Cannot unlink $old_logo_file: $!";
        }
    }
}

{
    # The uri can be either an external URI or just a path
    Readonly my $spec => { uri => SCALAR_TYPE };
    sub set_logo_from_uri {
        my $self = shift;
        my %p = validate( @_, $spec );

        return if $self->logo_uri and $self->logo_uri eq $p{uri};

        $self->_delete_existing_logo();

        local $self->{allow_logo_uri_update_HACK} = 1;
        $self->update( logo_uri => $p{uri} );
    }
}

sub _delete_existing_logo {
    my $self = shift;

    my $file = $self->logo_filename
        or return;

    unlink $file or die "Cannot unlink $file: $!";
}

#
# This particular file name scheme is designed so that by looking at
# the filename, we can know what workspace a logo belongs to, but it
# is not possible to snoop for logos by simply guessing workspace
# names and fishing for that URI. This means that we can (reasonably)
# safely serve the logos without checking authorization
#
sub _new_logo_filename {
    my $self = shift;
    my $type = shift;

    my $path = $self->_logo_path;
    my $filename = $self->name;
    $filename .= '-' . Digest::MD5::md5_hex( $self->name, Socialtext::AppConfig->MAC_secret );
    $filename .= ".$type";

    return Socialtext::File::catfile( $path, $filename );
}

sub LogoRoot {
    return Socialtext::File::catdir( Socialtext::AppConfig->data_root_dir, 'logos' );
}

sub _logo_path {
    my $self = shift;

    return Socialtext::File::catdir( $self->LogoRoot, $self->name );
}

sub title_label {
    my $self = shift;

    return
        $self->custom_title_label
        ? $self->custom_title_label
        : $self->permissions->is_public
        ? 'Eventspace'
        : 'Workspace';
}

sub creation_datetime_object {
    my $self = shift;

    return DateTime::Format::Pg->parse_timestamptz( $self->creation_datetime );
}

sub creator {
    my $self = shift;

    return Socialtext::User->new( user_id => $self->created_by_user_id );
}

sub account {
    my $self = shift;

    return Socialtext::Account->new( account_id => $self->account_id );
}

{
    Readonly my $spec => { uris => ARRAYREF_TYPE };
    sub set_ping_uris {
        my $self = shift;
        my %p = validate( @_, $spec );

        my @errors;
        my @uris;
        for my $uri ( grep { defined && length } @{ $p{uris} } ) {
            $uri = URI->new($uri)->canonical;
            unless ( $uri =~ m{^https?://} ) {
                push @errors, $uri . ' is not a valid weblog ping URI';
                next;
            }

            push @uris, $uri;
        }

        data_validation_error errors => \@errors if @errors;

        eval {
            sql_begin_work;
            sql_execute(
                'DELETE FROM "WorkspacePingURI" WHERE workspace_id = ?',
               $self->workspace_id,
            );

            for my $uri ( List::MoreUtils::uniq(@uris) ) {
                sql_execute(
                    'INSERT INTO "WorkspacePingURI" VALUES(?,?)',
                    $self->workspace_id,
                    $uri
                );
            }
            sql_commit;
        };

        if ( my $e = $@ ) {
            sql_rollback();
            rethrow_exception($e);
        }
    }
}

sub ping_uris {
    my $self = shift;

    my $sth = sql_execute(
        'SELECT uri FROM "WorkspacePingURI" WHERE workspace_id = ?',
        $self->workspace_id,
    );
    my $uris = $sth->fetchall_arrayref;
    return map { $_->[0] } @$uris;
}

{
    Readonly my $spec => { fields => ARRAYREF_TYPE };
    sub set_comment_form_custom_fields {
        my $self = shift;
        my %p = validate( @_, $spec );

        my @fields = grep { defined && length } @{ $p{fields} };

        eval {
            sql_begin_work;

            sql_execute(
                'DELETE FROM "WorkspaceCommentFormCustomField" '
                . 'WHERE workspace_id = ?',
                $self->workspace_id,
            );

            my $i = 1;
            for my $field ( List::MoreUtils::uniq(@fields) ) {
                sql_execute(
                    'INSERT INTO "WorkspaceCommentFormCustomField"
                        VALUES(?,?,?)',
                    $self->workspace_id, $field, $i++,
                );
            }
            sql_commit;
        };

        if ( my $e = $@ ) {
            sql_rollback();
            rethrow_exception($e);
        }
    }
}

sub plugins_enabled {
    my ($self) = @_;
    my $sql = q{
        SELECT plugin
          FROM workspace_plugin
         WHERE workspace_id = ?
    };
    my $result = sql_execute( $sql, $self->workspace_id );
    return map { $_->[0] } @{ $result->fetchall_arrayref };
}

sub is_plugin_enabled {
    my ($self, $plugin) = @_;
    my $sql = q{
        SELECT COUNT(*) FROM workspace_plugin
        WHERE workspace_id = ? AND plugin = ?
    };
    return sql_singlevalue($sql, $self->workspace_id, $plugin);
}

sub _check_plugin_scope {
    my $self = shift;
    my $plugin = shift;
    my $plugin_class = Socialtext::Pluggable::Adapter->plugin_class($plugin);
    die loc("The [_1] plugin can not be set at the workspace scope",
        $plugin) . "\n"
        unless $plugin_class->scope eq 'workspace';
}


sub enable_plugin {
    my ($self, $plugin) = @_;
    $self->_check_plugin_scope($plugin);

    my $plugin_class = Socialtext::Pluggable::Adapter->plugin_class($plugin);
    for my $dep ($plugin_class->dependencies) {
        $self->enable_plugin($dep);
    }

    if (!$self->is_plugin_enabled($plugin)) {
        Socialtext::Pluggable::Adapter->EnablePlugin($plugin => $self);

        sql_execute(q{
            INSERT INTO workspace_plugin VALUES (?,?)
        }, $self->workspace_id, $plugin);

        Socialtext::Cache->clear('authz_plugin');
    }
    my $msg = loc("The [_1] plugin is now enabled for workspace [_2]",
                  $plugin, $self->name);
    warn "$msg\n";
}

sub disable_plugin {
    my ($self, $plugin) = @_;
    $self->_check_plugin_scope($plugin);

    my $plugin_class = Socialtext::Pluggable::Adapter->plugin_class($plugin);
    for my $dep ($plugin_class->dependencies) {
        $self->enable_plugin($dep);
    }

    Socialtext::Pluggable::Adapter->DisablePlugin($plugin => $self);

    sql_execute(q{
        DELETE FROM workspace_plugin
        WHERE workspace_id = ? AND plugin = ?
    }, $self->workspace_id, $plugin);

    Socialtext::Cache->clear('authz_plugin');
}

sub comment_form_custom_fields {
    my $self = shift;

    my $sth = sql_execute(
        'SELECT field_name FROM "WorkspaceCommentFormCustomField"
            WHERE workspace_id = ?
            ORDER BY field_order',
        $self->workspace_id,
    );
    my $fields = $sth->fetchall_arrayref;
    return map { $_->[0] } @$fields;
}

sub permissions {
    my $self = shift;
    $self->{_perms} ||= Socialtext::Workspace::Permissions->new(wksp => $self);
    return $self->{_perms};
}

{
    Readonly my $spec => {
       user => USER_TYPE,
       role => ROLE_TYPE( default => undef ),
    };

    sub add_user {
        my $self = shift;
        my %p    = validate( @_, $spec );
        my $user = $p{user};

        $p{role} ||= Socialtext::Role->Member();

        $self->assign_role_to_user( is_selected => 1, %p );

        # This is needed because of older appliances where users were put in
        # one of three accounts that are not optimal:
        #
        #  * Ambiguous: They should be in an account, but more than one
        #    account seems like a good candidate.
        #  * General: There was not a good candidate account.
        #  * Unknown: This was an old default, move them if possible.
        #
        # We assume that's not where we want them to be, so assigning a user
        # to thier first workspace is a show of intent for which account they
        # should be in.
        $user->primary_account($self->account)
            if grep { $user->primary_account->name eq $_ }
            qw/Ambiguous General Unknown/;
    }
}

{
    Readonly my $spec => {
       user        => USER_TYPE,
       role        => ROLE_TYPE,
       is_selected => BOOLEAN_TYPE( default => 0 ),
    };
    sub assign_role_to_user {
        my $self = shift;
        my %p = validate( @_, $spec );
        my $timer = Socialtext::Timer->new;

        if ( $p{user}->is_system_created ) {
            param_error 'Cannot give a role to a system-created user';
        }

        if ( $p{role}->used_as_default ) {
            param_error 'Cannot explicitly assign a default role type to a user';
        }

        my $uwr = Socialtext::UserWorkspaceRole->new(
            user_id      => $p{user}->user_id,
            workspace_id => $self->workspace_id,
        );

        my $msg_action;
        if ($uwr) {
            $msg_action = 'CHANGE,USER_ROLE';

            $uwr->role_id($p{role}->role_id);
            $uwr->is_selected($p{is_selected});
            $uwr->update();
        }
        else {
            $msg_action = 'ASSIGN,USER_ROLE';

            Socialtext::UserWorkspaceRole->create(
                user_id      => $p{user}->user_id,
                workspace_id => $self->workspace_id,
                role_id      => $p{role}->role_id,
                is_selected  => $p{is_selected},
            );
        }

        Socialtext::Cache->clear('authz_plugin');

        st_log()->info($msg_action .  ','
             . 'role:' . $p{role}->name . ','
             . 'user:' . $p{user}->homunculus->username
             . '(' . $p{user}->user_id . '),'
             . 'workspace:' . $self->name . '('
             . $self->workspace_id . '),'
             . '[' . $timer->elapsed . ']');
    }
}

sub has_user {
    my $self = shift;
    my $user = shift; # [in] User

    my $sql = 'select 1 from "UserWorkspaceRole" where workspace_id = ? and user_id = ? and role_id <> ?';
    my $exists = sql_singlevalue(
        $sql,
        $self->workspace_id,
        $user->user_id,
        Socialtext::Role->Guest()->role_id(),
    );
    return (defined($exists) && $exists);
}

{
    Readonly my $spec => {
        user => USER_TYPE,
    };
    sub role_for_user {
        my $self = shift;
        my %p = validate( @_, $spec );

        my $sql = 'select role_id from "UserWorkspaceRole" where workspace_id = ? and user_id = ?';
        my $role_id = sql_singlevalue($sql, $self->workspace_id, $p{user}->user_id);
        return unless $role_id;

        return Socialtext::Role->new( role_id => $role_id );
    }

    sub remove_user {
        my $self = shift;
        my %p = validate( @_, $spec );
        my $timer = Socialtext::Timer->new;

        my $uwr = Socialtext::UserWorkspaceRole->new(
           workspace_id => $self->workspace_id,
           user_id      => $p{user}->user_id,
        );

        return unless $uwr;

        $uwr->delete;

        Socialtext::Cache->clear('authz_plugin');

        st_log()->info('REMOVE,USER_ROLE,'
             . 'user:' . $p{user}->homunculus->username
             . '(' . $p{user}->user_id . '),'
             . 'workspace:' . $self->name . '('
             . $self->workspace_id . '),'
             . '[' . $timer->elapsed . ']');
    }
}

{
    Readonly my $spec => {
       user        => USER_TYPE,
       role        => ROLE_TYPE,
    };
    sub user_has_role {
        my $self = shift;
        my %p = validate( @_, $spec );

        my $sql = 'select 1 from "UserWorkspaceRole" where workspace_id = ? and user_id = ? and role_id = ?';
        return sql_singlevalue($sql, $self->workspace_id, $p{user}->user_id, $p{role}->role_id()) || 0;
    }
}

sub user_count {
    my $self = shift;

    my $sth = sql_execute( <<EOT, $self->workspace_id );
SELECT COUNT( DISTINCT( "UserWorkspaceRole".user_id ) )
    FROM "UserWorkspaceRole"
    WHERE workspace_id = ?;
EOT
    return $sth->fetchall_arrayref->[0][0];
}

sub users {
    my $self = shift;

    my $sth = sql_execute(<<EOSQL, $self->workspace_id);
SELECT user_id, driver_username
    FROM users 
    JOIN "UserWorkspaceRole" uwr USING (user_id)
    WHERE uwr.workspace_id = ?
    ORDER BY driver_username
EOSQL

    return Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref ],
        apply => sub {
            my $row = shift;
            return Socialtext::User->new(
                user_id => $row->[0] );
        }
    );
}

sub users_with_roles {
    my $self = shift;

    return Socialtext::User->ByWorkspaceIdWithRoles(
            workspace_id => $self->workspace_id(), @_ );
}

{
    Readonly my $EXPORT_VERSION => 1;
    Readonly my $spec => {
        dir  => DIR_TYPE( default     => undef ),
        name => SCALAR_TYPE( optional => 1 )
    };
    sub export_to_tarball {
        my $self = shift;
        my %p = validate( @_, $spec );
        $p{name} ||= $self->name;
        $p{name} = lc $p{name};

        die loc("Export directory [_1] does not exist.\n", $p{dir}) 
	    if defined $p{dir} && ! -d $p{dir};

        die loc("Export directory [_1] is not writeable.\n", $p{dir})
            unless defined $p{dir} && -w $p{dir};

        my $tarball_dir
            = defined $p{dir} ? Cwd::abs_path( $p{dir} ) : $ENV{ST_TMP} || '/tmp';

        my $tarball = Socialtext::File::catfile( $tarball_dir,
            $p{name} . '.' . $EXPORT_VERSION . '.tar' );

        for my $file ( ($tarball, "$tarball.gz") ) {
            die loc("Cannot write export file [_1], aborting.\n", $file)
                if -f $file && ! -w $file;
        }

        $self->_create_export_tarball($tarball, $p{name});

        # pack up the tarball
        run "gzip --fast --force $tarball";

        return "$tarball.gz";
    }
}

sub _create_export_tarball {
    my $self = shift;
    my $tarball = shift;
    my $name = shift || $self->name;

    my $tmpdir = File::Temp::tempdir( CLEANUP => 1 );
    $self->_dump_to_yaml_file($tmpdir, $name);
    $self->_dump_users_to_yaml_file($tmpdir, $name);
    $self->_dump_permissions_to_yaml_file($tmpdir, $name);
    $self->_export_logo_file($tmpdir);
    local $CWD = $tmpdir;
    run "tar cf $tarball *";

    # Copy all the data for export into a the tempdir.
    local $CWD = Socialtext::AppConfig->data_root_dir();
    for my $dir (qw(plugin user data)) {
        if ($name eq $self->name) {
            # We can append directly to the tarball to save a copy
            run "tar rf $tarball "
                . Socialtext::File::catdir( $dir, $self->name );
        }
        else {
            # Copy the workspace data into the tmpdir, then add to the tarball
            my $src  = Socialtext::File::catdir( $dir,     $self->name );
            my $dest = Socialtext::File::catdir( $tmpdir, $dir, $name );
            dircopy( $src, $dest ) or die "Can't copy $src to $dest: $!\n";
            local $CWD = $tmpdir;
            run "tar rf $tarball " . Socialtext::File::catdir( $dir, $name );
        }
    }
}

sub _dump_to_yaml_file {
    my $self = shift;
    my $dir  = shift;
    my $name = shift || $self->name;

    my $file = Socialtext::File::catfile( $dir, $name . '-info.yaml' );

    my %dump;
    for my $c ( grep { $_ ne 'workspace_id' } @COLUMNS ) {
        $dump{$c} = $self->$c();
    }
    $dump{creator_username} = $self->creator->username;
    $dump{account_name} = $self->account->name;
    $dump{logo_filename} = File::Basename::basename( $self->logo_filename() )
        if $self->logo_filename();
    $dump{name} = $name;

    _dump_yaml( $file, \%dump );
}

sub _dump_yaml {
    my $file = shift;
    my $data = shift;

    open my $fh, '>:utf8', $file
        or die "Cannot write to $file: $!";
    print $fh YAML::Dump($data)
        or die "Cannot write to $file: $!";
    close $fh
        or die "Cannot write to $file: $!";
}

sub _dump_users_to_yaml_file {
    my $self = shift;
    my $dir = shift;
    my $name = shift || $self->name;

    my $file = Socialtext::File::catfile( $dir, $name . '-users.yaml' );

    my $users_with_roles = $self->users_with_roles;
    my @dump;
    while ( 1 ) {
        my $elem = $users_with_roles->next;
        my $user = $elem->[0];
        my $role = $elem->[1];
        last unless defined $user;

        my $dump = $user->to_hash;
        delete $dump->{user_id};
        $dump->{role_name} = $role->name;
        push @dump, $dump;
    }

    _dump_yaml( $file, \@dump );
}

sub _dump_permissions_to_yaml_file {
    my $self = shift;
    my $dir  = shift;
    my $name = shift || $self->name;

    my $file = Socialtext::File::catfile( $dir, $name . '-permissions.yaml' );

    my $sth = sql_execute(<<EOT, $self->workspace_id);
SELECT role_id, permission_id from "WorkspaceRolePermission"
    WHERE workspace_id = ?
EOT
    my $rows = $sth->fetchall_arrayref;

    my @dump;
    for my $r (@$rows) {
        push @dump, {
            role_name => Socialtext::Role->new( role_id => $r->[0] )->name,
            permission_name => Socialtext::Permission->new( 
                permission_id => $r->[1])->name,
        }
    }

    _dump_yaml( $file, \@dump );
}

sub _export_logo_file {
    my $self = shift;
    my $dir  = shift;
    if ( my $logo_file = $self->logo_filename() ) {

        # chdir'ing and just using a relative path prevents tar
        # from giving us warnings about absolute path names.
        local $CWD = File::Basename::dirname($logo_file);
        my $basename = File::Basename::basename($logo_file);
        my $new_logo = Socialtext::File::catdir( $dir, $basename );

        File::Copy::copy( $logo_file, $new_logo )
            or die "Could not copy $logo_file to $new_logo: $!\n";
    }
}

sub Any {
    my $class = shift;

    return $class->All( limit => 1 )->next;
}

sub ImportFromTarball {
    shift;

    require Socialtext::Workspace::Importer;

    Socialtext::Workspace::Importer->new(@_)->import_workspace();
}

sub AllWorkspaceIdsAndNames {
    my $sth = sql_execute('SELECT workspace_id, name FROM "Workspace" where workspace_id <> 0 ORDER BY name');
    return $sth->fetchall_arrayref() || [];
}

my %LimitAndSortSpec = (
    limit      => SCALAR_TYPE( default => undef ),
    offset     => SCALAR_TYPE( default => 0 ),
    order_by   => SCALAR_TYPE(
        regex   => qr/^(?:name|user_count|account_name|creation_datetime|creator)$/,
        default => 'name',
    ),
    sort_order => SCALAR_TYPE(
        regex   => qr/^(?:ASC|DESC|)$/i,
        default => undef,
    ),
);
{
    Readonly my $spec => { %LimitAndSortSpec };
    sub All {
        my $class = shift;
        my %p = validate( @_, $spec );

        # We're supposed to default to DESCending if we're creation_datetime.
        $p{sort_order} ||= $p{order_by} eq 'creation_datetime' ? 'DESC' : 'ASC';

        Readonly my %SQL => (
            name => 'SELECT *'
                . ' FROM "Workspace"'
                . " ORDER BY name $p{sort_order}"
                . ' LIMIT ? OFFSET ?',
            creation_datetime => 'SELECT *'
                . ' FROM "Workspace"'
                . " ORDER BY creation_datetime $p{sort_order},"
                . ' name ASC'
                . ' LIMIT ? OFFSET ?',
            account_name => 'SELECT "Workspace".*'
                . ' FROM "Workspace", "Account"'
                . ' WHERE "Workspace".account_id = "Account".account_id'
                . " ORDER BY \"Account\".name $p{sort_order},"
                . ' "Workspace".name ASC'
                . ' LIMIT ? OFFSET ?',
            creator => 'SELECT *'
                . ' FROM "Workspace", users'
                . ' WHERE created_by_user_id=user_id'
                . " ORDER BY driver_username $p{sort_order}, name ASC"
                . ' LIMIT ? OFFSET ?',
            user_count => 'SELECT "Workspace".*'
                . ' FROM "Workspace",'
                . ' (SELECT workspace_id, COUNT(DISTINCT("UserWorkspaceRole".user_id))'
                . ' AS user_count FROM "UserWorkspaceRole" GROUP BY workspace_id) AS temp1'
                . ' WHERE temp1.workspace_id = "Workspace".workspace_id'
                . " ORDER BY user_count $p{sort_order},"
                . ' "Workspace".name ASC'
                . ' LIMIT ? OFFSET ?',
        );

        return $class->_WorkspaceCursor(
            $SQL{ $p{order_by} },
            [qw( limit offset)], %p
        );
    }
}

sub _WorkspaceCursor {
    my ( $class, $sql, $interpolations, %p ) = @_;

    my $sth = sql_execute( $sql, @p{@$interpolations} );

    return Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref( {} ) ],
        apply => sub {
            my $row = shift;
            return Socialtext::Workspace->_new_from_hash_ref( $row );
        }
    );
}

{
    Readonly my $spec => {
        %LimitAndSortSpec,
        order_by   => SCALAR_TYPE(
            regex   => qr/^(?:name|user_count|creation_datetime|creator|account_name)$/,
            default => 'name',
        ),
        account_id => SCALAR_TYPE,
    };
    sub ByAccountId {
        my $class = shift;
        my %p = validate( @_, $spec );

        # We're supposed to default to DESCending if we're creation_datetime.
        $p{sort_order} ||= $p{order_by} eq 'creation_datetime' ? 'DESC' : 'ASC';

        Readonly my %SQL => (
            name => 'SELECT *'
                . ' FROM "Workspace"'
                . ' WHERE account_id=?'
                . " ORDER BY name $p{sort_order}"
                . ' LIMIT ? OFFSET ?',
            creation_datetime => 'SELECT *'
                . ' FROM "Workspace"'
                . ' WHERE account_id=?'
                . " ORDER BY creation_datetime $p{sort_order},"
                . ' name ASC'
                . ' LIMIT ? OFFSET ?',
            account_name => 'SELECT "Workspace".*'
                . ' FROM "Workspace", "Account"'
                . ' WHERE "Workspace".account_id = "Account".account_id'
                . ' AND "Workspace".account_id=?'
                . " ORDER BY \"Account\".name $p{sort_order},"
                . ' "Workspace".name ASC'
                . ' LIMIT ? OFFSET ?',
            creator => 'SELECT *'
                . ' FROM "Workspace", users'
                . ' WHERE created_by_user_id=user_id'
                . ' AND "Workspace".account_id=?'
                . " ORDER BY driver_username $p{sort_order}, name ASC"
                . ' LIMIT ? OFFSET ?',
            user_count => 'SELECT "Workspace".*'
                . ' FROM "Workspace",'
                . ' (SELECT workspace_id, COUNT(DISTINCT("UserWorkspaceRole".user_id))'
                . ' AS user_count FROM "UserWorkspaceRole" GROUP BY workspace_id) AS temp1'
                . ' WHERE temp1.workspace_id = "Workspace".workspace_id'
                . " AND \"Workspace\".account_id=?"
                . " ORDER BY user_count $p{sort_order},"
                . ' "Workspace".name ASC'
                . ' LIMIT ? OFFSET ?',
        );

        return $class->_WorkspaceCursor(
            $SQL{ $p{order_by} },
            [qw( account_id limit offset )], %p
        );
    }
}

{
    Readonly my $spec => {
        %LimitAndSortSpec,
        name => SCALAR_TYPE,
        case_insensitive => SCALAR_TYPE( default => 0),
    };
    sub ByName {
        my $class = shift;
        my %p = validate( @_, $spec );

        # We're supposed to default to DESCending if we're creation_datetime.
        $p{sort_order} ||= $p{order_by} eq 'creation_datetime' ? 'DESC' : 'ASC';

        my $op = $p{case_insensitive} ? 'ILIKE' : 'LIKE';
        Readonly my %SQL => (
            name => 'SELECT *'
                . ' FROM "Workspace"'
                . " WHERE name $op ?"
                . " ORDER BY name $p{sort_order}"
                . ' LIMIT ? OFFSET ?',
            creation_datetime => 'SELECT *'
                . ' FROM "Workspace"'
                . " WHERE name $op ?"
                . " ORDER BY creation_datetime $p{sort_order},"
                . ' name ASC'
                . ' LIMIT ? OFFSET ?',
            account_name => 'SELECT "Workspace".*'
                . ' FROM "Workspace", "Account"'
                . ' WHERE "Workspace".account_id = "Account".account_id'
                . " AND \"Workspace\".name $op ?"
                . " ORDER BY \"Account\".name $p{sort_order},"
                . ' "Workspace".name ASC'
                . ' LIMIT ? OFFSET ?',
            creator => 'SELECT *'
                . ' FROM "Workspace", users'
                . ' WHERE created_by_user_id=user_id'
                . " AND \"Workspace\".name $op ?"
                . " ORDER BY driver_username $p{sort_order}, name ASC"
                . ' LIMIT ? OFFSET ?',
            user_count => <<EOSQL,
SELECT *
    FROM "Workspace" LEFT OUTER JOIN (
        SELECT workspace_id, COUNT(DISTINCT("UserWorkspaceRole".user_id))
            AS user_count
            FROM "UserWorkspaceRole"
            GROUP BY workspace_id
        ) AS X USING (workspace_id)
    WHERE name $op ?
    ORDER BY user_count $p{sort_order}, "Workspace".name ASC
    LIMIT ? OFFSET ?
EOSQL
        );

        # Turn our substring into a SQL pattern.
        $p{name} = '%' . $p{name} . '%';

        return $class->_WorkspaceCursor(
            $SQL{ $p{order_by} },
            [qw( name limit offset )], %p
        );
    }
}

sub Count {
    my $class = shift;
    my $sth = sql_execute('SELECT COUNT(*) FROM "Workspace" where workspace_id <> 0');
    return $sth->fetchrow_arrayref->[0];
}

sub CountByName {
    my $class = shift;
    my %p = @_;
    my $op = $p{case_insensitive} ? 'ILIKE' : 'LIKE';
    my $sth = sql_execute('SELECT COUNT(*) FROM "Workspace" WHERE name ' . $op . ' \'%' . $p{name} . '%\'');
    return $sth->fetchrow_arrayref->[0];
}

sub MostOftenAccessedLastWeek {
    my $self = shift;
    my $limit = shift || 10;
    my $sth = sql_execute(q{
        SELECT "Workspace".title AS workspace_title,
               "Workspace".name AS workspace_name
        FROM (
            SELECT distinct page_workspace_id,
                   COUNT(*) AS views
              FROM event
             WHERE event_class = 'page'
               AND action = 'view'
               AND at > 'now'::timestamptz - '1 week'::interval
             GROUP BY page_workspace_id
             ORDER BY views DESC
             LIMIT ?
        ) AS X
        JOIN "Workspace"
          ON workspace_id = page_workspace_id
        JOIN "WorkspaceRolePermission"
          USING(workspace_id)
        JOIN "Permission"
          USING(permission_id)
        JOIN "Role"
          USING(role_id)
        WHERE "Permission".name = 'read'
          AND "Role".name = 'guest'
        ORDER BY views DESC;
    }, $limit);

    my @viewed;
    while (my $row = $sth->fetchrow_hashref) {
        push @viewed, [$row->{workspace_name}, $row->{workspace_title}];
    }
    return @viewed;
}

use constant RECENT_WORKSPACES => 10;
sub read_breadcrumbs {
    my ( $self, $user ) = @_;

    # Get the crumbs
    my @list = Socialtext::WorkspaceBreadcrumb->List(
        user_id => $user->user_id,
        limit   => RECENT_WORKSPACES,
    );

    # Seed the list if we didn't get much.  We'll always at least get the
    # workspace we're on now.
    unless (@list > 1) {
        @list = $self->prepopulate_breadcrumbs($user);
        @list = @list[ 0 .. ( RECENT_WORKSPACES - 1 ) ]
            if @list > RECENT_WORKSPACES;
    }

    return @list;
}

sub prepopulate_breadcrumbs {
    my ( $self, $user ) = @_;
    my @workspaces = $user->workspaces( selected_only => 1 )->all();

    for my $ws ( reverse @workspaces ) {
        Socialtext::WorkspaceBreadcrumb->Save(
            user_id      => $user->user_id,
            workspace_id => $ws->workspace_id,
        );
    }

    return @workspaces;
}

sub drop_breadcrumb {
    my $self = shift;
    my $user = shift;

    Socialtext::WorkspaceBreadcrumb->Save(
        user_id      => $user->user_id,
        workspace_id => $self->workspace_id,
    );
}

package Socialtext::NoWorkspace;
use strict;
use warnings;

use base 'Socialtext::Workspace';
use Class::Field qw(const);
use Socialtext::SQL 'sql_execute';
use Socialtext::User;
use Socialtext::SystemSettings qw(get_system_setting);

const name => '';
const title => 'The NoWorkspace Workspace';
const account_id => 1;
const workspace_id => 0;
const email_addresses_are_hidden => 0;
const real => 0;

sub skin_name { '' }

sub created_by_user_id {
    Socialtext::User->SystemUser->user_id;
}

my @COLS = qw(
    workspace_id name title account_id skin_name created_by_user_id
);

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    my $sth = sql_execute(qq{SELECT * FROM "Workspace" WHERE workspace_id = 0});
    my $row = $sth->fetchrow_arrayref;
    unless ($row) {
        my $keys = join ', ', @COLS;
        my $vals = join ', ', map { '?' } @COLS;
        my $sql = qq{
            INSERT INTO "Workspace" ( $keys )
            VALUES ( $vals )
        };
        sql_execute($sql, map { $self->$_ } @COLS );
    }
    return $self;
}

sub _set_workspace_option { return 1; }

1;

__END__

=head1 NAME

Socialtext::Workspace - A Socialtext workspace object

=head1 SYNOPSIS

  use Socialtext::Workspace;

  my $workspace = Socialtext::Workspace->new( workspace_id => $workspace_id );

  my $workspace = Socialtext::Workspace->new( name => $name );

=head1 DESCRIPTION

This class provides methods for dealing with data from the Workspace
table. Each object represents a single row from the table.

A workspace has the following attributes:

=head2 name

This is used when generating URIs and when sending email to a
workspace. It must be 3 to 30 characters long, and must match
C</^[A-Za-z0-9_\-]+$/>. Also, it cannot conflict with an existing
email alias.

=head2 title

This is used as the title of the home page for the workspace, and is
also used in various contexts when referring to the workspace, for
example in recent changes email notifications. The title must be 2-64
characters in length.

=head2 email_addresses_are_hidden

If this is true, then user's email addresses are always masked when
they're displayed. The domain name is replaced by "@hidden".

=head2 email_weblog_dot_address

If this is true, then the workspace will accept email for weblogs
using the 'workspace.CAT.category@server.domain.com' format - this
is to support Lotus Notes, Exchange and other non-standard email
clients.

=head2 comment_by_email

If this is true, the 'Add comment' links on pages and weblog entries will
contain C<mailto:> links pointing at the email-in address for the current
workspace.

=head2 unmasked_email_domain

If this is set to a domain name, then email addresses in this domain
are never hidden.

=head2 prefers_incoming_html_email

When this is true, if an incoming email has both text and HTML
versions, the HTML version is saved as the page's body.

=head2 incoming_email_placement

This specifies how an incoming email that matches an existing page
name is saved. This can be one of "top", "bottom", or "replace". The
"top" and "bottom" options cause the email to be added to the existing
page at the specified location, while "replace" replaces existing
pages.

=head2 allows_html_wafl

Specifies whether the ".html" WAFL block is allowed in a workspace.

=head2 email_notify_is_enabled

Specifies whether email notifications are turned on for this
workspace.

=head2 sort_weblogs_by_create

If true, weblogs are sorted by page creation time. Otherwise they are
sorted by the last updated time of each page's most recent revision.

=head2 external_links_open_new_window

If this is true, links outside of NLW open a new browser window.

=head2 basic_search_only

If this is true, then the workspace is not indexed using a search factory, and
searching uses the "basic" mechanism.

=head2 header_image_logo_filename

The filename of the image to be shown in the page header, which is
different from the logo image shown in the page's side pane. This
defaults to the Socialtext logo (F<logo-bar-12.gif>), but this
attribute can be overridden as needed.

=head2 show_welcome_message_below_logo

If this is true, the welcome message ("Welcome, Faye Wong") is shown
below the workspace logo in the side pane. Otherwise it is shown in
the fixed bar at the top of the page.

=head2 custom_title_label

By default, a workspace's title is prefixed with either "Workspace:"
or "Eventspace:". Setting this changes this to a custom value. A
trailing colon is always added to this value in the display code, so
do not include it in the value of this attribute.

=head2 show_title_below_logo

if this is true, then the workspace title is shown below the logo in
the side pane.

=head2 comment_form_note_bottom

When set, the text will be displayed at the bottom of the comment for textarea in the UI.

=head2 comment_form_note_top

When set, the text will be displayed at the top of the comment for textarea in the UI.

=head2 comment_form_window_height

The comment form window will popup to this hieght.

=head2 email_notification_from_address

When set, this value is used as the "From" header when sending email
notifications. Otherwise, the default value of
"noreply@socialtext.net" is used.

=head2 skin_name

The skin defines a set of CSS files, and possibly javascript and
templates. The default skin is "st". For now, the skin_name is just
used to generate filesystem and URI paths to the various files.

In the future, this will be replaced with something more
sophisticated, when skins become first class entities in the system.

=head2 enable_unplugged

If set to a true value, enable_unplugged will cause the workspace to
display icons that, when clicked, will generate a zip archive of a
tiddlytext version of the relevant pages from the workspace. A tiddlytext
is a version of TiddlyWiki for editing Socialtext workspaces pages offline
and then syncing them back to the server.

=head2 logo_uri

The URI to the workspace's logo.

This cannot be set via C<create()> or C<update()>. Use
C<set_logo_from_file()> or C<set_logo_from_uri()> instead.

=head2 creation_datetime

The datetime at which the workspace was created.

=head2 account_id

The account_id of the Account to which this workspace belongs.

=head2 created_by_user_id

The user_id of the user who created this workspace.

=head2

=head1 METHODS

=head2 Socialtext::Workspace->new(PARAMS)

Looks for an existing workspace matching PARAMS and returns a
C<Socialtext::Workspace> object representing that workspace if it
exists.

PARAMS can be I<one> of:

=over 4

=item * workspace_id => $workspace_id

=item * name => $name

=back

=head2 Socialtext::Workspace->NameIsValid(PARAMS)

Validates whether a workspace name is valid according to syntax rules.
It also checks the name against a list of reserved names.  The method
returns 1 if the name is valid, 0 if it is not.

If the name is invalid and an arrayref is passed as errors, a
description of each violated rule will be stored in the arrayref.

It DOES NOT check to see if a workspace exists.

PARAMS can include:

=over 4

=item * name => $name - required

=item * errors => \@errors - optional, an arrayref where violated constraints will be put

=back

=head2 Socialtext::Workspace->TitleIsValid(PARAMS)

Validates whether a workspace title is valid according to syntax rules.
It also checks the title against a list of reserved titles.  The method
returns 1 if the title is valid, 0 if it is not.

If the title is invalid and an arrayref is passed as errors, a
description of each violated rule will be stored in the arrayref.

It DOES NOT check to see if a workspace exists.

PARAMS can include:

=over 4

=item * title => $title - required

=item * errors => \@errors - optional, an arrayref where violated constraints will be put

=back

=head2 Socialtext::Workspace->create(PARAMS)

Attempts to create a workspace with the given information and returns
a new C<Socialtext::Workspace> object representing the new workspace.

PARAMS can include:

=over 4

=item * name - required

=item * title - required

=item * email_addresses_are_hidden - defaults to 0

=item * unmasked_email_domain - optional

=item * prefers_incoming_html_email - defaults to 0

=item * incoming_email_placement - defaults to "bottom"

=item * allows_html_wafl - defaults to 1

=item * email_notify_is_enabled - defaults to 1

=item * sort_weblogs_by_create - defaults to 0

=item * external_links_open_new_window - defaults to 1

=item * basic_search_only - defaults to 0

=item * email_weblog_dot_address - defaults to 0

=item * show_welcome_message_below_logo - defaults to 0

=item * custom_title_label - defaults to ""

=item * show_title_below_logo - defaults to 1

=item * email_notification_from_address - defaults to ""

=item * skin_name - defaults to "st"

=item * creation_datetime - defaults to CURRENT_TIMESTAMP

=item * account_id - defaults to Socialtext::Account->Unknown()->account_id()

=item * created_by_user_id - defaults to Socialtext::User->SystemUser()->user_id()

=item * skip_default_pages - defaults to false

=item * clone_pages_from - clone pages from another workspace, defaults to false

=item * enable_unplugged - defaults to 0

=back

Creating a workspace creates the necessary paths on the filesystem,
and copies the tutorial pages and workspace home page into the new
workwspace. It also calls C<< Socialtext::EmailAlias::create_alias() >> to
add its name to the aliases file.

If "skip_default_pages" is true, then the usual tutorial and default
home page for the workspace will not be created. This option is
primarily intended for one-time use when importing existing workspaces
into the DBMS.

=head2 Socialtext::Workspace->help_workspace( ARGS )

Return the help workspace for the current system-wide locale().  This method
takes the same arguments as new(), sans the name argument, which will be
ignored.

=head2 $workspace->update(PARAMS)

Updates the workspace's information with the new key/val pairs passed
in.

Note that to rename a workspace you should call the C<rename()>
method.

=head2 $workspace->rename( name => $new_name )

This renames a workspace in the DBMS, as well as on the filesystem and
in the email aliases file.

=head2 $workspace->workspace_id()

=head2 $workspace->name()

=head2 $workspace->title()

=head2 $workspace->logo_uri()

=head2 $workspace->email_addresses_are_hidden()

=head2 $workspace->unmasked_email_domain()

=head2 $workspace->prefers_incoming_html_email()

=head2 $workspace->incoming_email_placement()

=head2 $workspace->allows_html_wafl()

=head2 $workspace->email_notify_is_enabled()

=head2 $workspace->sort_weblogs_by_create()

=head2 $workspace->external_links_open_new_window()

=head2 $workspace->basic_search_only()

=head2 $workspace->email_weblog_dot_address()

=head2 $workspace->show_welcome_message_below_logo()

=head2 $workspace->custom_title_label()

Call C<< $workspace->title_label() >> instead to get either the
default or custom label, as appropriate.

=head2 $workspace->show_title_below_logo()

=head2 $workspace->email_notification_from_address()

Defaults to 'noreply@socialtext.com' via ST::Schema.

=head2 $workspace->formatted_email_notification_from_address()

Returns a formatted address comprising the title of the Workspace and
the address set via email_notification_from_address.

=head2 $workspace->skin_name()

=head2 $workspace->enable_unplugged()

=head2 $workspace->creation_datetime()

=head2 $workspace->account_id()

=head2 $workspace->created_by_user_id()

Returns the given attribute for the workspace.

=head2 $workspace->title_label()

If the workspace has a custom title label, this is returned. Otherwise
this returns either "Workspace" or "Eventspace", depending on
the workspace's ACLs.

=head2 $workspace->delete()

Deleting a workspace also deletes any workspace data on the
filesystem, as well as its email alias.

=head2 $workspace->uri()

Returns the full URI for the workspace, using the "http" scheme. The
hostname is taken from C<< Socialtext::AppConfig->web_hostname >>.

=head2 $workspace->email_in_address()

Returns the email address for mailing pages into the workspace. The
email hostname comes from C<< Socialtext::AppConfig->email_hostname >>.

=head2 $workspace->header_logo_image_uri()

Returns a URI for the header logo. This is based on the value of the
"header_logo_image_filename" attribute.

=head2 $workspace->logo_uri_or_default()

Returns a valid logo URI for the workspace, using a default of
F</static/images/socialtext-logo-30.gif> if the workspace does not
have its own custom logo.

=head2 $workspace->logo_filename()

If the workspace has a custom logo on the filesystem, then this
methods returns that file's absolute path, otherwise it returns false.

=head2 $workspace->set_logo_from_file(PARAMS)

This method expects one parameter, a "filename". The specified file
should contain the image data, and will be used for determining the 
file's type, which must be a GIF, JPEG or PNG.

The image is resized to a maximum size of 200px wide by 60px high, and
saved on the filesystem in a location accessible from the web. The
workspace's logo_uri will be set to match the URI of this file.

The URI will contain a portion based on an MD5 digest in order to make
snooping for logos much more difficult.

If the workspace has an existing logo on the filesystem,
this will be deleted.

=head2 $workspace->set_logo_from_uri( uri => $uri )

This simply sets the workspace's logo_uri to the given "uri"
parameter. If the workspace has an existing logo on the filesystem,
this will be deleted.

=head2 $workspace->ping_uris()

Returns a list of the ping URIs for the workspace.

=head2 $workspace->set_ping_uris( uris => [ $uri1, $uri2 ] )

This method sets the ping URIs for the workspace (used by the
C<Socialtext::WeblogUpdates> module.

=head2 $workspace->comment_form_custom_fields()

Returns a list of the comment form fustom fields for the workspace.

=head2 $workspace->set_comment_form_custom_fields( fields => [ $field1, $field2 ] )

This method sets comment form custom fields for the workspace.

=head2 Socialtext::Workspace->LogoRoot()

Returns the path under which logos are stored.

=head2 $workspace->creation_datetime_object()

Returns a new C<DateTime.pm> object for the workspace's creation
datetime.

=head2 $workspace->creator()

Returns the C<Socialtext::User> object for the user which created this
workspace.

=head2 $workspace->account()

Returns the C<Socialtext::Account> object for the account to which the
workspace belongs.

=head2 $workspace->set_permissions( set_name => $name )

Given a permission-set name, this method sets the workspace's
permissions according to the definition of that set.

The valid set names and the permissions they give are shown below.
Additionally, all permission sets give the same permissions as C<member> plus
C<impersonate> to the C<impersonator> role.

=head2 $workspace->is_plugin_enabled($plugin)

Returns true if the specified plugin is enabled for this workspace.

=head2 $workspace->enable_plugin($plugin)

Enables the plugin for the specified workspace.

=head2 $workspace->disable_plugin($plugin)

Disables the plugin for the specified workspace.

=head2 $account->plugins_enabled()

Returns an array for the plugins enabled.

=head2 $workspace->enable_spreadsheet()

Check whether spreadsheets are enabled or not.

=over 4

=item * public

=over 8

=item o guest - read, edit, comment

=item o authenticated_user - read, edit, comment, email_in

=item o member - read, edit, attachments, comment, delete, email_in, email_out

=item o workspace_admin - read, edit, attachments, comment, delete, email_in, email_out

=back

=item * member-only

=over 8

=item o guest - none

=item o authenticated_user - email_in

=item o member - read, edit, attachments, comment, delete, email_in, email_out

=item o workspace_admin - read, edit, attachments, comment, delete, email_in, email_out

=back

=item * authenticated-user-only

=over 8

=item o guest - none

=item o authenticated_user - read, edit, attachments, comment, delete, email_in, email_out

=item o member - read, edit, attachments, comment, delete, email_in, email_out

=item o workspace_admin - read, edit, attachments, comment, delete, email_in, email_out

=back

=item * public-read-only

=over 8

=item o guest - read

=item o authenticated_user - read

=item o member - read, edit, attachments, comment, delete, email_in, email_out

=item o workspace_admin - read, edit, attachments, comment, delete, email_in, email_out

=back

=item * public-comment-only

=over 8

=item o guest - read, comment

=item o authenticated_user - read, comment

=item o member - read, edit, attachments, comment, delete, email_in, email_out

=item o workspace_admin - read, edit, attachments, comment, delete, email_in, email_out

=back

=item * public-authenticate-to-edit

=over 8

=item o guest - read, edit_controls

=item o authenticated_user - read, edit, attachments, comment, delete, email_in, email_out

=item o member - read, edit, attachments, comment, delete, email_in, email_out

=item o workspace_admin - read, edit, attachments, comment, delete, email_in, email_out

=back

=item * intranet

=over 8

=item o guest - read, edit, attachments, comment, delete, email_in, email_out

=item o authenticated_user - read, edit, attachments, comment, delete, email_in, email_out

=item o member - read, edit, attachments, comment, delete, email_in, email_out

=item o workspace_admin - read, edit, attachments, comment, delete, email_in, email_out

=back

=back

Additionally, when a name that starts with public is given, this
method will also change allows_html_wafl and email_notify_is_enabled
to false.

=head2 $workspace->add_user( user => $user, role => $role )

Adds the user to the workspace with the given role. If no role is
specified, this defaults to "member". UserWorkspaceRole.is_selected
will be true for this user and workspace.

=head2 $workspace->assign_role_to_user( user => $user, role => $role, is_selected => $bool )

Assigns the specified role to the given user. The value of is_selected
defaults to 0. If the user already has a role for this workspace, this
method changes that role.

=head2 $workspace->has_user( $user )

Returns a boolean indicating whether or not the user has an explicitly
assigned role for this workspace.

=head2 $workspace->role_for_user( user => $user )

Returns the C<Socialtext::Role> for this user in the workspace if they
have an explicitly assigned role. Otherwise it returns false.

=head2 $workspace->remove_user( user => $user )

Removes an explicitly assigned role for the user in this workspace, if
they have one.

=head2 $workspace->user_has_role( user => $user, role => $role )

Returns a boolean indicating whether or not the user has the given
role.

=head2 $workspace->user_count()

Returns the number of users with an explicitly assigned role in the
workspace.

=head2 $workspace->users()

Returns a cursor of C<Socialtext::User> objects for users in the
workspace, ordered by username.

=head2 $workspace->users_with_roles()

Returns a cursor of C<Socialtext::User> and
C<Socialtext::UserWorkspaceRole> objects for users in the the
workspace, ordered by username.

=head2 $workspace->to_hash()

Returns a hash reference representation of the workspace, suitable
for using with JSON, YAML, etc.

=head2 $workspace->export_to_tarball( dir => $dir, [name => $name] )

This method exports the workspace as a tarball. This tarball can be
restored by calling C<< Socialtext::Workspace->ImportFromTarball() >>.

The "dir" parameter is optional, and if none is given, it will use a
temp directory.

The "name" parameter is optional.  If it is given the exported tarball uses
Workspace name $name instead of workspace's actual name.  When the tarball is
re-imported it will have name $name.

This method returns the full path to the created tarball.

The exported data includes the workspace data, pages, user data for
all users who are members of the workspace, and the roles for those
users.

=head2 $workspace->real()

Real workspaces return true, NoWorkspaces return false.

=head2 Socialtext::Workspace->Any()

Returns one workspace at random. This was needed for interfacing with
the C<Socialtext::Hub> object, which always needs a workspace object, but in
some cases you may not care I<which> workspace you use.

=head2 Socialtext::Workspace->ImportFromTarball( tarball => $file, overwrite => $bool )

Given a tarball produced by C<< $workspace->export_to_tarball() >>,
this method will create a workspace based on that export.

If the workspace already exists, it throws an exception, but you can
force it to overwrite this workspace by passing "overwrite" as a true
value.

It never overwrites existing users.

=head2 Socialtext::Workspace->AllWorkspaceIdsAndNames()

Returns an array ref of workspace ID and name pairs.  These pairs are also
array refs.

=head2 Socialtext::Workspace->All(PARAMS)

Returns a cursor for all the workspaces in the system. It accepts the
following parameters:

=over 4

=item * limit and offset

These parameters can be used to add a C<LIMIT> clause to the query.

=item * order_by - defaults to "name"

This must be one "name", "user_count", "account_name",
"creation_datetime", or "creator".

=item * sort_order - "ASC" or "DESC"

This defaults to "ASC" except when C<order_by> is "creation_datetime",
in which case it defaults to "DESC".

=back

=head2 Socialtext::Workspace->ByAccountId(PARAMS)

Returns a cursor for all the workspaces in the specified account.

This accepts the same parameters as C<< Socialtext::Workspace->All()
>>, but requires an additional "account_id" parameter. When this
method is called, the C<order_by> parameter may not be "account_name".

=head2 Socialtext::Workspace->ByName(PARAMS)

Returns a cursor for all the workspaces matching the specified string.

This accepts the same parameters as C<< Socialtext::Workspace->All()
>>, but requires an additional "name" parameter. Any workspaces
containing the specified string anywhere in their name will be
returned.

=head2 Socialtext::Workspace->Count()

Returns the number of workspaces in the system.

=head2 Socialtext::Workspace->CountByName( name => $name )

Returns the number of workspaces in the system containing the
specified string anywhere in their name.

=head2 Socialtext::Workspace->MostOftenAccessedLastWeek($limit)

Returns a list of the most often accessed I<public> workspaces.  Restricted to
the C<$limit> (default 10) most often accessed public workspaces, accessed
over the last week.

Returned as a list of list-refs that contain the "name" and "title" of the
workspace.

=head2 Socialtext::Workspace->read_breadcrumbs( USER )

Returns the list of recently viewed workspaces for the user

=head2 Socialtext::Workspace->prepopulate_breadcrumbs( USER )

If the user's breadcrumbs list is emptry, this routine will add the first 10
workspaces to the breadcrumb list.

=head2 Socialtext::Workspace->write_breadcrumbs( USER, BREAD )

Save the user's breadcrumb list

=head2 Socialtext::Workspace->drop_breadcrumb( USER )

Add a workspace breadcrumb to the user's list

=head2 Socialtext::Workspace->_new_from_hash_ref(hash)

Returns a new instantiation of a Workspace object. Data members for the
object are initialized from the hash reference passed to the method.

=head2 Socialtext::Workspace->permissions()

Return a Socialtext::Workspace::Permission object

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005 Socialtext, Inc., All Rights Reserved.

=cut

