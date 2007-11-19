# @COPYRIGHT@
package Socialtext::Workspace;

use strict;
use warnings;

our $VERSION = '0.01';


use Socialtext::Exceptions qw( rethrow_exception param_error data_validation_error );
use Socialtext::Validate qw( validate validate_pos SCALAR_TYPE BOOLEAN_TYPE ARRAYREF_TYPE HANDLE_TYPE
                             URI_TYPE USER_TYPE ROLE_TYPE PERMISSION_TYPE FILE_TYPE DIR_TYPE UNDEF_TYPE );

use Socialtext::Schema;
use base 'Socialtext::AlzaboWrapper';
__PACKAGE__->SetAlzaboTable( Socialtext::Schema->Load()->table('Workspace') );
__PACKAGE__->MakeColumnMethods();

use Alzabo::Runtime::ForeignKey;
use Alzabo::SQLMaker::PostgreSQL qw( COUNT DISTINCT LOWER CURRENT_TIMESTAMP );
use Class::Field 'field';
use Cwd ();
use DateTime;
use DateTime::Format::Pg;
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
use Socialtext::CSS;
use Socialtext::EmailAlias;
use Socialtext::File;
use Socialtext::File::Copy::Recursive qw(dircopy);
use Socialtext::Helpers;
use Socialtext::Image;
use Socialtext::l10n qw(loc system_locale);
use Socialtext::Log qw( st_log );
use Socialtext::Paths;
use Socialtext::SQL qw( sql_execute );
use Socialtext::String;
use Readonly;
use Socialtext::Account;
use Socialtext::AlzaboWrapper::Cursor::PKOnly;
use Socialtext::Permission qw( ST_EMAIL_IN_PERM ST_READ_PERM );
use Socialtext::Role;
use Socialtext::URI;
use Socialtext::MultiCursor;
use Socialtext::User;
use Socialtext::UserWorkspaceRole;
use Socialtext::WorkspaceBreadcrumb;
use URI;

field breadcrumbs => '';

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
    else {
        return $class->SUPER::new(%args);
    }
}

sub table_name { 'Workspace' }

sub _new_row {
    my $class = shift;
    my %p     = validate( @_, { name => SCALAR_TYPE } );

    return $class->table->one_row(
        where => [ LOWER( $class->table->column('name') ), '=', lc $p{name } ],
    );
}

sub create {
    my $class = shift;
    my %p = @_;

    my $schema = Socialtext::Schema->Load();

    my $skip_pages = delete $p{skip_default_pages};

    my $self;
    eval {
        $schema->begin_work();

        $self = $class->SUPER::create(%p);

        my $creator = $self->creator;
        unless ( $creator->is_system_created ) {
            $self->add_user(
                user => $creator,
                role => Socialtext::Role->WorkspaceAdmin(),
            );
        }

        $self->set_permissions( set_name => 'member-only' );

        $schema->commit();
    };

    if ( my $e = $@ ) {
        $schema->rollback();
        rethrow_exception($e);
    }

    $self->_make_fs_paths();
    $self->_copy_default_pages()
        unless $skip_pages;
    $self->_update_aliases_file();

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

sub _copy_default_pages {
    my $self = shift;
    my ( $main, $hub ) = $self->_main_and_hub();

    # Load up the help workspace, and a corresponding hub.
    my $help      = Socialtext::Workspace->help_workspace() || return;
    my $help_hub = Socialtext->new->load_hub(
        current_workspace => $help,
        current_user      => $hub->current_user,
    );
    $help_hub->registry->load;

    # Get all the default pages from the help workspace
    my @pages = $help_hub->category->get_pages_for_category( loc("Welcome") );
    push @pages, $help_hub->category->get_pages_for_category( loc("Top Page") );

    # Duplicate the pages
    for my $page (@pages) {
        my $title = $page->title;

        # Top Page is special.  We need to name the page after the current
        # workspace, not "Top Page", and we need to add the current workspace
        # title to the page content (there's some TT2 in the wikitext).
        if ( $page->id eq 'top_page' ) {
            $title = $self->title;
            my $content = $page->content;
            my $content_formatted = $hub->template->process(
                \$content,
                workspace_title => $self->title
            );
            $page->content($content_formatted);
            $page->metadata->Category([]);
        } else {
            $page->metadata->delete_category("Top Page");
            $page->metadata->add_category("Recent Changes");
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

#sub customjs_uri {
#    my $self = shift;
#
#    return $self->{customjs_uri};
#}

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

    my $old_title = $self->title();

    $self->SUPER::update(@_);

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


# REVIEW: turn a workspace into a hash suitable for JSON and
# such things.
# REVIEW: An Alzabo thing won't serialize directly, we
# need to make queries or otherwise dig into it, so not sure
# what to put in this hash
# REVIEW: We may want even more info than this.
sub to_hash {
    my $self = shift;
    my $hash = {};
    foreach my $column ($self->columns) {
        my $name = $column->name;
        my $value = $self->$name();
        $hash->{$name} = "$value"; # to_string on some objects
    }
    return $hash;
}

sub delete {
    my $self = shift;

    for my $dir ( $self->_data_dir_paths() ) {
        File::Path::rmtree($dir);
    }

    Socialtext::EmailAlias::delete_alias( $self->name );

    $self->SUPER::delete();
}

my %ReservedNames = map { $_ => 1 } qw(
    account
    administrate
    administrator
    alzabo
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
            . ' Use set_logo_from_filehandle() or set_logo_from_uri().';
    }

    if ( defined $p->{name} and not $is_create and not $self->{allow_rename_HACK} ) {
        die "Cannot rename workspace via update(). Use rename() instead.";
    }

    my @errors;
    for my $k ( qw( name title ) ) {
        $p->{$k} = Socialtext::String::trim( $p->{$k} )
            if defined $p->{$k};

        if ( ( exists $p->{$k} or $is_create )
             and not
             ( defined $p->{$k} and length $p->{$k} ) ) {
            push @errors, loc("Workspace [_1] is a required field.", $k);
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

    if (
        defined $p->{title}
        and (  length $p->{title} < 2
            or length $p->{title} > 64
            or $p->{title} =~ /^-/ )
        ) {
        push @errors,
            loc(
            'Workspace title must be between 2 and 64 characters long and may not begin with a -.'
            );
    }

    if ( $p->{incoming_email_placement}
         and $p->{incoming_email_placement} !~ /^(?:top|bottom|replace)$/ ) {
        push @errors, loc('Incoming email placement must be one of top, bottom, or replace.');
    }

    if ( $p->{skin_name}
         && ! 1 # Socialtext::Skin->new( name => $p->{skin_name} )
       ) {
        push @errors, loc("The skin you specified,[_1], does not exist.", $p->{skin_name});
    }

    if ( $is_create and not $p->{account_id} ) {
        push @errors, loc("An account must be specified for all new workspaces.");
    }

    data_validation_error errors => \@errors if @errors;

    if ( $p->{logo_uri} ) {
        $p->{logo_uri} = URI->new( $p->{logo_uri} )->canonical . '';
    }

    if ($is_create) {
        $p->{created_by_user_id} ||= Socialtext::User->SystemUser()->user_id();
    }
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

        my $old_name  = $self->name();
        my @old_paths = $self->_data_dir_paths();

        local $self->{allow_rename_HACK} = 1;
        $self->update( name => $p{name} );

        my @new_paths = $self->_data_dir_paths();

        for ( my $x = 0; $x < @old_paths; $x++ ) {
            rename $old_paths[$x] => $new_paths[$x]
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
    }
}

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

Readonly my $DefaultLogoURI => '/static/images/st/logo/socialtext-logo-152x26.gif';
sub logo_uri_or_default {
    my $self = shift;

    return $self->logo_uri if $self->logo_uri;

    return $DefaultLogoURI;
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


    sub set_logo_from_filehandle {
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
        eval {
            Socialtext::Image::resize(
                filehandle => $p{filehandle},
                max_width  => 200,
                max_height => 60,
                file       => $new_file,
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

# This sort of stuff will eventually move to Socialtext::Skin, once
# that exists.
sub header_logo_image_uri {
    my $self = shift;

    my $logo_file = Socialtext::File::catfile(
        Socialtext::AppConfig->code_base(), 'images',
        $self->skin_name, 'logo-bar-12.gif' );

    if ( -f $logo_file ) {
        return join '/',
            Socialtext::Helpers->static_path,
            'images',
            $self->skin_name,
            'logo-bar-12.gif';
    }

    return join '/',
        Socialtext::Helpers->static_path,
        'images',
        'logo-bar-12.gif';
}

sub title_label {
    my $self = shift;

    return
        $self->custom_title_label
        ? $self->custom_title_label
        : $self->is_public
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

        my $schema = Socialtext::Schema->Load();
        my $wtu = $schema->table('WorkspacePingURI');

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
            $schema->begin_work;

            my $driver = Socialtext::Schema->Load()->driver();

            my $sql = 'DELETE FROM ' . $driver->quote_identifier( $wtu->name )
                      . 'WHERE workspace_id = ?';

            $driver->do( sql => $sql, bind => $self->workspace_id );

            for my $uri ( List::MoreUtils::uniq(@uris) ) {
                $wtu->insert( values => { workspace_id => $self->workspace_id,
                                          uri          => $uri } );
            }

            $schema->commit;
        };

        if ( my $e = $@ ) {
            $schema->rollback();
            rethrow_exception($e);
        }
    }
}

{
    Readonly my $spec => { fields => ARRAYREF_TYPE };
    sub set_comment_form_custom_fields {
        my $self = shift;
        my %p = validate( @_, $spec );

        my $schema = Socialtext::Schema->Load();
        my $wtf = $schema->table('WorkspaceCommentFormCustomField');
        my @fields = grep { defined && length } @{ $p{fields} };

        eval {
            $schema->begin_work;

            my $driver = Socialtext::Schema->Load()->driver();

            my $sql = 'DELETE FROM ' . $driver->quote_identifier( $wtf->name )
                      . 'WHERE workspace_id = ?';

            $driver->do( sql => $sql, bind => $self->workspace_id );

            my $i = 1;
            for my $field ( List::MoreUtils::uniq(@fields) ) {
                $wtf->insert( values => { workspace_id => $self->workspace_id,
                                          field_name   => $field,
                                          field_order  => $i++} );
            }

            $schema->commit;
        };

        if ( my $e = $@ ) {
            $schema->rollback();
            rethrow_exception($e);
        }
    }
}

sub ping_uris {
    my $self = shift;

    my $wtu = Socialtext::Schema->Load()->table('WorkspacePingURI');
    return $wtu->function(
        select => $wtu->column('uri'),
        where  => [ $wtu->column('workspace_id'), '=', $self->workspace_id ],
    );
}

sub comment_form_custom_fields {
    my $self = shift;

    my $wtf = Socialtext::Schema->Load()->table('WorkspaceCommentFormCustomField');
    return $wtf->function(
        select => $wtf->column('field_name'),
        where  => [ $wtf->column('workspace_id'), '=', $self->workspace_id ],
        order_by => [ $wtf->column('field_order') ],
    );
}

{
    my %PermissionSets = (
        'public' => {
            guest              => [ qw( read edit comment ) ],
            authenticated_user => [ qw( read edit comment email_in ) ],
            member             => [ qw( read edit attachments comment delete email_in email_out ) ],
            workspace_admin    => [ qw( read edit attachments comment delete email_in email_out admin_workspace ) ],
        },
        'member-only' => {
            guest              => [ ],
            authenticated_user => [ 'email_in' ],
            member             => [ qw( read edit attachments comment delete email_in email_out ) ],
            workspace_admin    => [ qw( read edit attachments comment delete email_in email_out admin_workspace ) ],
        },
        'authenticated-user-only' => {
            guest              => [ ],
            authenticated_user => [ qw( read edit attachments comment delete email_in email_out ) ],
            member             => [ qw( read edit attachments comment delete email_in email_out ) ],
            workspace_admin    => [ qw( read edit attachments comment delete email_in email_out admin_workspace ) ],
        },
        'public-read-only' => {
            guest              => [ 'read' ],
            authenticated_user => [ 'read' ],
            member             => [ qw( read edit attachments comment delete email_in email_out ) ],
            workspace_admin    => [ qw( read edit attachments comment delete email_in email_out admin_workspace ) ],
        },
        'public-comment-only' => {
            guest              => [ qw( read comment ) ],
            authenticated_user => [ qw( read comment ) ],
            member             => [ qw( read edit attachments comment delete email_in email_out ) ],
            workspace_admin    => [ qw( read edit attachments comment delete email_in email_out admin_workspace ) ],
        },
        'public-authenticate-to-edit' => {
            guest              => [ qw( read edit_controls ) ],
            authenticated_user => [ qw( read edit attachments comment delete email_in email_out ) ],
            member             => [ qw( read edit attachments comment delete email_in email_out ) ],
            workspace_admin    => [ qw( read edit attachments comment delete email_in email_out admin_workspace ) ],
        },
        'intranet' => {
            guest              => [ qw( read edit attachments comment delete email_in email_out ) ],
            authenticated_user => [ qw( read edit attachments comment delete email_in email_out ) ],
            member             => [ qw( read edit attachments comment delete email_in email_out ) ],
            workspace_admin    => [ qw( read edit attachments comment delete email_in email_out admin_workspace ) ],
        },
    );

    my @PermissionSetsLocalize = (loc('public'), loc('member-only'), loc('authenticated-user-only'), loc('public-read-only'), loc('public-comment-only'), loc('public-authenticate-to-edit') ,loc('intranet'));

    # Impersonators should be able to do everything members can do, plus
    # impersonate.
    $_->{impersonator} = [ 'impersonate', @{ $_->{member} } ]
        for values %PermissionSets;

    Readonly my $spec => {
        set_name => {
            callbacks => {
                 'valid permission set name' =>
                 sub { $_[0] && exists $PermissionSets{ $_[0] } },
            },
        },
    };
    sub set_permissions {
        my $self = shift;
        my %p = validate( @_, $spec );

        my $set = $PermissionSets{ $p{set_name} };

        my $schema = Socialtext::Schema->Load();

        my $wrp_table = $schema->table('WorkspaceRolePermission');
        my $current_perms =
            $wrp_table->rows_where(
                where => [ $wrp_table->column('workspace_id'),
                           '=', $self->workspace_id ]
            );

        eval {
            $schema->begin_work();

            my $guest_id = Socialtext::Role->Guest()->role_id();
            my $email_in_id = ST_EMAIL_IN_PERM->permission_id();

            # XXX - Alzabo is lame and does not provide table-level
            # update and delete, which really needs to be corrected in
            # a near-future release.
            my $has_existing_perms = 0;
            while ( my $wrp = $current_perms->next ) {
                next
                    if $wrp->select('role_id') == $guest_id
                    and $wrp->select('permission_id') eq $email_in_id;

                $wrp->delete;

                $has_existing_perms = 1;
            }

            for my $role_name ( keys %$set ) {
                my $role = Socialtext::Role->new( name => $role_name );

                for my $perm_name ( @{ $set->{$role_name} } ) {
                    my $perm = Socialtext::Permission->new( name => $perm_name );

                    next
                        if $role_name  eq 'guest'
                        and $perm_name eq 'email_in'
                        and $has_existing_perms;

                    $wrp_table->insert(
                        values => {
                            workspace_id  => $self->workspace_id,
                            role_id       => $role->role_id,
                            permission_id => $perm->permission_id,
                        },
                    );
                }
            }

            # XXX - maybe this belongs in a higher-level API that in
            # turn calls set_permissions
            if ( $p{set_name} =~ /^public/ ) {
                $self->update(
                    allows_html_wafl           => 0,
                    email_notify_is_enabled    => 0,
                    email_addresses_are_hidden => 1,
                    homepage_is_dashboard      => 0,
                );
            }

            $schema->commit();
        };

        if ( my $e = $@ ) {
            $schema->rollback();
            rethrow_exception($e);
        }
    }

    # This is just caching to make current_permission_set_name run at a
    # reasonable speed.
    my %SetsAsStrings =
        map { $_ => _perm_set_as_string( $PermissionSets{$_} ) }
        keys %PermissionSets;

    sub current_permission_set {
        my $self = shift;
        my $perms_with_roles = $self->permissions_with_roles();

        my %set;
        while ( my $pair = $perms_with_roles->next ) {
            my ( $perm, $role ) = @$pair;
            push @{ $set{ $role->name() } }, $perm->name();
        }

        # We need the contents of %set to match our pre-defined sets,
        # which assign an empty arrayref for a role when it has no
        # permissions (see authenticated-user-only).
        my $roles = Socialtext::Role->All();
        while ( my $role = $roles->next() ) {
            $set{ $role->name() } ||= [];
        }

        return %set;
    }

    sub current_permission_set_name {
        my $self = shift;

        my %set = $self->current_permission_set;

        my $set_string = _perm_set_as_string( \%set );
        for my $name ( keys %SetsAsStrings ) {
            return $name if $SetsAsStrings{$name} eq $set_string;
        }

        return 'custom';
    }

    sub _perm_set_as_string {
        my $set = shift;

        my @parts;
        # This particular string dumps nicely, the newlines are not
        # special or anything.
        for my $role ( sort keys %{$set} ) {
            my $string = "$role: ";
            # We explicitly ignore the email_in permission as applied
            # to guests when determining the set string so that it
            # does not affect the calculated set name for a
            # workspace. See RT 21831.
            my @perms = sort @{ $set->{$role} };
            @perms = grep { $_ ne 'email_in' } @perms
                if $role eq 'guest';

            $string .= join ', ', @perms;

            push @parts, $string;
        }

        return join "\n", @parts;
    }

    sub PermissionSetNameIsValid {
        my $class = shift;
        my $name  = shift;

        return $PermissionSets{$name} ? 1 : 0;
    }
}

{
    Readonly my $spec => {
        permission => PERMISSION_TYPE,
        role       => ROLE_TYPE,
    };
    sub add_permission {
        my $self = shift;
        my %p = validate( @_, $spec );

        my $wrp_table = Socialtext::Schema->Load()->table('WorkspaceRolePermission');
        eval {
            $wrp_table->insert(
                values => {
                    workspace_id  => $self->workspace_id,
                    role_id       => $p{role}->role_id,
                    permission_id => $p{permission}->permission_id,
                },
            );
        };

        if ( my $e = $@ ) {
            rethrow_exception($e)
                unless $e =~ /duplicate key/;
        }
    }

    sub remove_permission {
        my $self = shift;
        my %p = validate( @_, $spec );

        my $wrp_table = Socialtext::Schema->Load()->table('WorkspaceRolePermission');
        my $row = $wrp_table->row_by_pk( pk => {
            workspace_id  => $self->workspace_id,
            role_id       => $p{role}->role_id,
            permission_id => $p{permission}->permission_id,
        } );
        $row->delete if $row;
    }

    sub role_has_permission {
        my $self = shift;
        my %p = validate( @_, $spec );

        my $wrp_table = Socialtext::Schema->Load()->table('WorkspaceRolePermission');
        return $wrp_table->function(
            select => 1,
            where  => [
                [ $wrp_table->column('workspace_id'), '=', $self->workspace_id ],
                [ $wrp_table->column('role_id'), '=', $p{role}->role_id ],
                [ $wrp_table->column('permission_id'), '=', $p{permission}->permission_id ],
            ],
        ) ? 1 : 0;
    }
}

{
    Readonly my $spec => {
        role => ROLE_TYPE,
    };
    sub permissions_for_role {
        my $self = shift;

        my %p = validate( @_, $spec );

        my $sth = sql_execute(
            'SELECT permission_id'
            . ' FROM "WorkspaceRolePermission"'
            . ' WHERE workspace_id=? AND role_id=?',
            $self->workspace_id, $p{role}->role_id );

        return Socialtext::MultiCursor->new(
            iterables => [ $sth->fetchall_arrayref ],
            apply     => sub {
                my $row = shift;
                return Socialtext::Permission->new(
                    permission_id => $row->[0] );
            }
        );
    }
}

sub permissions_with_roles {
    my $self = shift;

    my $sth = sql_execute(
        'SELECT permission_id, role_id'
        . ' FROM "WorkspaceRolePermission"'
        . ' WHERE workspace_id=?',
        $self->workspace_id);

    return Socialtext::MultiCursor->new(
        iterables => [ $sth->fetchall_arrayref ],
        apply     => sub {
            my $row = shift;
            my $permission_id = $row->[0];
            my $role_id = $row->[1];

            # warn "# Row $row pid $permission_id rid $role_id\n";
            return undef unless defined $permission_id;

            return [
                Socialtext::Permission->new( permission_id => $permission_id ),
                Socialtext::Role->new( role_id             => $role_id )
            ];
        }
    );
}

{
    Readonly my $spec => {
        user       => USER_TYPE,
        permission => PERMISSION_TYPE,
    };
    sub user_has_permission {
        my $self = shift;
        my %p = validate( @_, $spec );

        my $schema = Socialtext::Schema->Load();

        my $uwr_table  = $schema->table('UserWorkspaceRole');
        my $wrp_table  = $schema->table('WorkspaceRolePermission');
        my $fk = Alzabo::Runtime::ForeignKey->new(
            columns_from => [ $uwr_table->columns( 'workspace_id', 'role_id' ) ],
            columns_to   => [ $wrp_table->columns( 'workspace_id', 'role_id' ) ],
        );

        my $has_permission =
            $schema->function(
                select => 1,
                join   => [ [ $uwr_table, $wrp_table, $fk ] ],
                where  => [
                    [ $uwr_table->column('user_id'), '=', $p{user}->user_id() ],
                    [ $uwr_table->column('workspace_id'), '=', $self->workspace_id() ],
                    [ $wrp_table->column('permission_id'), '=', $p{permission}->permission_id() ],
                ],
            );

        return 1 if $has_permission;

        return 1
            if $self->role_has_permission(
                role       => $p{user}->default_role,
                permission => $p{permission},
            );
    }
}

sub is_public {
    my $self = shift;

    return 1
        if $self->role_has_permission(
            role       => Socialtext::Role->Guest(),
            permission => ST_READ_PERM,
        );
}

{
    Readonly my $spec => {
       user => USER_TYPE,
       role => ROLE_TYPE( default => undef ),
    };

    sub add_user {
        my $self = shift;
        my %p = validate( @_, $spec );
        $p{role} ||= Socialtext::Role->Member();

        $self->assign_role_to_user( is_selected => 1, %p );
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

        if ($uwr) {
            my $msg = join ' : ', 'CHANGE_USER_ROLE', $self->workspace_id,
                $p{user}->user_id, $p{role}->role_id;
            st_log()->info($msg);

            $uwr->update(
                role_id     => $p{role}->role_id,
                is_selected => $p{is_selected},
            );
        }
        else {
            my $msg = join ' : ', 'ADD_USER', $self->workspace_id,
                $p{user}->user_id, $p{role}->role_id;
            st_log()->info($msg);

            Socialtext::UserWorkspaceRole->create(
                user_id      => $p{user}->user_id,
                workspace_id => $self->workspace_id,
                role_id      => $p{role}->role_id,
                is_selected  => $p{is_selected},
            );
        }
    }
}

sub has_user {
    my $self = shift;
    my $user = shift; # [in] User

    my $uwr_table = Socialtext::Schema->Load()->table('UserWorkspaceRole');
    return 1 if
        $uwr_table->row_count(
            where => [
                [ $uwr_table->column('workspace_id'), '=', $self->workspace_id ],
                [ $uwr_table->column('user_id'), '=', $user->user_id ],
                [ $uwr_table->column('role_id'), '!=', Socialtext::Role->Guest()->role_id() ],
            ],
        );
}

{
    Readonly my $spec => {
        user => USER_TYPE,
    };
    sub role_for_user {
        my $self = shift;
        my %p = validate( @_, $spec );

        my $uwr_table = Socialtext::Schema->Load()->table('UserWorkspaceRole');
        my $role_id =
            $uwr_table->function(
                select => $uwr_table->column('role_id'),
                where => [
                    [ $uwr_table->column('workspace_id'), '=', $self->workspace_id ],
                    [ $uwr_table->column('user_id'), '=', $p{user}->user_id ],
                ],
            );

        return unless $role_id;

        return Socialtext::Role->new( role_id => $role_id );
    }

    sub remove_user {
        my $self = shift;
        my %p = validate( @_, $spec );

        my $uwr = Socialtext::UserWorkspaceRole->new(
           workspace_id => $self->workspace_id,
           user_id      => $p{user}->user_id,
        );

        return unless $uwr;

        my $msg = join ' : ', 'REMOVE_USER', $self->workspace_id,
            $p{user}->user_id;
        st_log()->info($msg);

        $uwr->delete;
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

        my $uwr_table = Socialtext::Schema->Load()->table('UserWorkspaceRole');
        return 1 if
            $uwr_table->row_count(
                where => [
                    [ $uwr_table->column('workspace_id'), '=', $self->workspace_id ],
                    [ $uwr_table->column('user_id'), '=', $p{user}->user_id ],
                    [ $uwr_table->column('role_id'), '=', $p{role}->role_id() ],
                ],
            );
    }
}

sub user_count {
    my $self = shift;

    my $uwr_table = Socialtext::Schema->Load()->table('UserWorkspaceRole');

    return $uwr_table->function(
        select => COUNT( DISTINCT( $uwr_table->column('user_id') ) ),
        where  => [ $uwr_table->column('workspace_id'), '=', $self->workspace_id ],
    );
}

sub users {
    my $self = shift;

    my $schema = Socialtext::Schema->Load();

    return Socialtext::MultiCursor->new(
        iterables => [
            $schema->join(
                select => [ $schema->tables(qw( UserId )) ],
                join   => [ $schema->tables(qw( UserWorkspaceRole UserId )) ],
                where  => [
                    $schema->table('UserWorkspaceRole')
                        ->column('workspace_id'),
                    '=', $self->workspace_id
                ],
                order_by =>
                    $schema->table('UserId')->column('driver_username'),
            )
        ],
        apply => sub {
            my $row = shift;
            return Socialtext::User->new(
                user_id => $row->select('system_unique_id') );
        }
    );
}

sub users_with_roles {
    my $self = shift;

    return
        Socialtext::User->ByWorkspaceIdWithRoles(
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

        my $tarball_dir
            = defined $p{dir} ? Cwd::abs_path( $p{dir} ) : $ENV{ST_TMP} || '/tmp';

        my $tarball = Socialtext::File::catfile( $tarball_dir,
            $p{name} . '.' . $EXPORT_VERSION . '.tar' );

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
    for my $c ( grep { $_ ne 'workspace_id' } map { $_->name } $self->columns ) {
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

        my %dump = %{$user->to_hash};
        delete $dump{'user_id'};
        $dump{creator_username} = $user->creator->username;
        $dump{role_name} = $role->name;

        my $file = Socialtext::File::catfile( $dir, $user->username . '-info.yaml' );

        push @dump, \%dump;
    }

    _dump_yaml( $file, \@dump );
}

sub _dump_permissions_to_yaml_file {
    my $self = shift;
    my $dir  = shift;
    my $name = shift || $self->name;

    my $file = Socialtext::File::catfile( $dir, $name . '-permissions.yaml' );

    my $wrp_table = Socialtext::Schema->Load()->table('WorkspaceRolePermission');
    my $current_perms =
        $wrp_table->rows_where(
            where => [ $wrp_table->column('workspace_id'),
                       '=', $self->workspace_id ],
        );

    my @dump;
    while ( my $wrp = $current_perms->next ) {
        push @dump, {
            role_name       =>
            Socialtext::Role->new( role_id => $wrp->select('role_id') )->name,
            permission_name =>
            Socialtext::Permission->new( permission_id => $wrp->select('permission_id') )->name,
        };
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
            name => 'SELECT workspace_id'
                . ' FROM "Workspace"'
                . " ORDER BY name $p{sort_order}"
                . ' LIMIT ? OFFSET ?',
            creation_datetime => 'SELECT workspace_id'
                . ' FROM "Workspace"'
                . " ORDER BY creation_datetime $p{sort_order},"
                . ' name ASC'
                . ' LIMIT ? OFFSET ?',
            account_name => 'SELECT "Workspace".workspace_id'
                . ' FROM "Workspace", "Account"'
                . ' WHERE "Workspace".account_id = "Account".account_id'
                . " ORDER BY \"Account\".name $p{sort_order},"
                . ' "Workspace".name ASC'
                . ' LIMIT ? OFFSET ?',
            creator => 'SELECT workspace_id'
                . ' FROM "Workspace", "UserId"'
                . ' WHERE created_by_user_id=system_unique_id'
                . " ORDER BY driver_username $p{sort_order}, name ASC"
                . ' LIMIT ? OFFSET ?',
            user_count => 'SELECT "Workspace".workspace_id,'
                . ' COUNT(DISTINCT("UserWorkspaceRole".user_id)) AS user_count'
                . ' FROM "Workspace"'
                . ' LEFT OUTER JOIN "UserWorkspaceRole"'
                . ' ON "Workspace".workspace_id = "UserWorkspaceRole".workspace_id'
                . ' GROUP BY "Workspace".workspace_id, "Workspace".name'
                . " ORDER BY user_count $p{sort_order}, \"Workspace\".name ASC"
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
        iterables => [ $sth->fetchall_arrayref ],
        apply => sub {
            my $row = shift;
            return Socialtext::Workspace->new( workspace_id => $row->[0] );
        }
    );
}

{
    Readonly my $spec => {
        %LimitAndSortSpec,
        order_by   => SCALAR_TYPE(
            regex   => qr/^(?:name|user_count|creation_datetime|creator)$/,
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
            name => 'SELECT workspace_id'
                . ' FROM "Workspace"'
                . ' WHERE account_id=?'
                . " ORDER BY name $p{sort_order}"
                . ' LIMIT ? OFFSET ?',
            creation_datetime => 'SELECT workspace_id'
                . ' FROM "Workspace"'
                . ' WHERE account_id=?'
                . " ORDER BY creation_datetime $p{sort_order},"
                . ' name ASC'
                . ' LIMIT ? OFFSET ?',
            account_name => 'SELECT "Workspace".workspace_id'
                . ' FROM "Workspace", "Account"'
                . ' WHERE "Workspace".account_id = "Account".account_id'
                . ' AND "Workspace".account_id=?'
                . " ORDER BY \"Account\".name $p{sort_order},"
                . ' "Workspace".name ASC'
                . ' LIMIT ? OFFSET ?',
            creator => 'SELECT workspace_id'
                . ' FROM "Workspace", "UserId"'
                . ' WHERE created_by_user_id=system_unique_id'
                . ' AND "Workspace".account_id=?'
                . " ORDER BY driver_username $p{sort_order}, name ASC"
                . ' LIMIT ? OFFSET ?',
            user_count => 'SELECT "Workspace".workspace_id,'
                . ' COUNT(DISTINCT("UserWorkspaceRole".user_id)) AS user_count'
                . ' FROM "Workspace"'
                . ' LEFT OUTER JOIN "UserWorkspaceRole"'
                . ' ON "Workspace".workspace_id = "UserWorkspaceRole".workspace_id'
                . ' WHERE account_id=?'
                . ' GROUP BY "Workspace".workspace_id, "Workspace".name'
                . " ORDER BY user_count $p{sort_order}, \"Workspace\".name ASC"
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
    };
    sub ByName {
        my $class = shift;
        my %p = validate( @_, $spec );

        # We're supposed to default to DESCending if we're creation_datetime.
        $p{sort_order} ||= $p{order_by} eq 'creation_datetime' ? 'DESC' : 'ASC';

        Readonly my %SQL => (
            name => 'SELECT workspace_id'
                . ' FROM "Workspace"'
                . ' WHERE name LIKE ?'
                . " ORDER BY name $p{sort_order}"
                . ' LIMIT ? OFFSET ?',
            creation_datetime => 'SELECT workspace_id'
                . ' FROM "Workspace"'
                . ' WHERE name LIKE ?'
                . " ORDER BY creation_datetime $p{sort_order},"
                . ' name ASC'
                . ' LIMIT ? OFFSET ?',
            account_name => 'SELECT "Workspace".workspace_id'
                . ' FROM "Workspace", "Account"'
                . ' WHERE "Workspace".account_id = "Account".account_id'
                . ' AND "Workspace".name LIKE ?'
                . " ORDER BY \"Account\".name $p{sort_order},"
                . ' "Workspace".name ASC'
                . ' LIMIT ? OFFSET ?',
            creator => 'SELECT workspace_id'
                . ' FROM "Workspace", "UserId"'
                . ' WHERE created_by_user_id=system_unique_id'
                . ' AND "Workspace".name LIKE ?'
                . " ORDER BY driver_username $p{sort_order}, name ASC"
                . ' LIMIT ? OFFSET ?',
            user_count => 'SELECT "Workspace".workspace_id,'
                . ' COUNT(DISTINCT("UserWorkspaceRole".user_id)) AS user_count'
                . ' FROM "Workspace"'
                . ' LEFT OUTER JOIN "UserWorkspaceRole"'
                . ' ON "Workspace".workspace_id = "UserWorkspaceRole".workspace_id'
                . ' WHERE name LIKE ?'
                . ' GROUP BY "Workspace".workspace_id, "Workspace".name'
                . " ORDER BY user_count $p{sort_order}, \"Workspace\".name ASC"
                . ' LIMIT ? OFFSET ?',
        );

        # Turn our substring into a SQL pattern.
        $p{name} = "\%$p{name}\%";

        return $class->_WorkspaceCursor(
            $SQL{ $p{order_by} },
            [qw( name limit offset )], %p
        );
    }
}

{
    Readonly my $spec => { name => SCALAR_TYPE( regex => qr/\S/ ) };
    sub CountByName {
        my $class = shift;
        my %p = validate( @_, $spec );

        my $ws_table = Socialtext::Schema->Load()->table('Workspace');

        return $ws_table->row_count(
            where => [ $ws_table->column('name'), 'LIKE', '%' . $p{name} . '%' ],
        );
    }
}

use constant RECENT_WORKSPACES => 10;
sub read_breadcrumbs {
    my ( $self, $user ) = @_;

    # Returned the cached result if we have one.
    my $list = $self->breadcrumbs || [];
    return @$list if $list and @$list;

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

    # Cache the result and return the list.
    $self->breadcrumbs( \@list );
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
C<set_logo_from_filehandle()> or C<set_logo_from_uri()> instead.

=head2 creation_datetime

The datetime at which the workspace was created.

=head2 account_id

The account_id of the Account to which this workspace belongs.

=head2 created_by_user_id

The user_id of the user who created this workspace.

=head2

=head1 METHODS

=head2 Socialtext::Workspace->table_name()

Returns the name of the table where Workspace data lives.

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

=head2 $workspace->set_logo_from_filehandle(PARAMS)

This method expects two parameters, "filehandle" and "filename". The
handle given should be opened for reading, and should contain the
image data for the logo.

The filename is used for determining the file's type, which must be a
GIF, JPEG, or PNG.

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

=head2 $workspace->current_permission_set()

Returns the workspace's current permission set as a hash.

=head2 $workspace->current_permission_set_name()

Returns the name of the workspace's current permission set. If it does
not match any of the pre-defined sets this method returns "custom".

=head2 Socialtext::Workspace->PermissionSetNameIsValid($name)

Returns a boolean indicating whether or not the given set name is
valid.

=head2 $workspace->add_permission( permission => $perm, role => $role );

This methods adds the given permission for the specified role.

=head2 $workspace->remove_permission( permission => $perm, role => $role );

This methods removes the given permission for the specified role.

=head2 $workspace->role_has_permission( permission => $perm, role => $role );

Returns a boolean indicating whether the specified role has the given
permission.

=head2 $workspace->permissions_with_roles

Returns a cursor of C<Socialtext::Permission> and C<Socialtext::Role>
objects indicating the permissions for each role in the workspace.

=head2 $workspace->permissions_for_role( role => $role );

Returns a cursor of C<Socialtext::Permission> objects indicating what
permissions the specified role has in this workspace.

=head2 $workspace->user_has_permission( permission => $perm, user => $user );

Returns a boolean indicating whether the specified user has the given
permission. This is based on the user's role in workspace. If the user
has no explicit role, then it uses the value of C<<
$user->default_role >>.

=head2 $workspace->is_public()

This returns true if guests have the "read" permission for the workspace.

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

=head2 Socialtext::Workspace->breadcrumbs_path( USER )

Returns the path to the user's workspace breadcrumb file.

=head2 Socialtext::Workspace->read_breadcrumbs( USER )

Returns the list of recently viewed workspaces for the user

=head2 Socialtext::Workspace->prepopulate_breadcrumbs( USER )

If the user's breadcrumbs list is emptry, this routine will add the first 10
workspaces to the breadcrumb list.

=head2 Socialtext::Workspace->write_breadcrumbs( USER, BREAD )

Save the user's breadcrumb list

=head2 Socialtext::Workspace->drop_breadcrumb( USER )

Add a workspace breadcrumb to the user's list

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005 Socialtext, Inc., All Rights Reserved.

=cut
