package Socialtext::Workspace::Importer;
# @COPYRIGHT@

use strict;
use warnings;

use Encode::Guess qw( ascii iso-8859-1 utf8 );
use File::chdir;
use Socialtext::File::Copy::Recursive ();
use Readonly;
use Socialtext::Validate qw( validate FILE_TYPE BOOLEAN_TYPE SCALAR_TYPE );
use Socialtext::Workspace;
use YAML ();

# This should stay in sync with $EXPORT_VERSION in ST::Workspace.
Readonly my $MAX_VERSION => 1;

{
    Readonly my $spec => {
        name      => SCALAR_TYPE(optional => 1),
        tarball   => FILE_TYPE,
        overwrite => BOOLEAN_TYPE( default => 0 ),
    };
    sub new {
        my $class = shift;
        my %p = validate( @_, $spec );

        die "Tarball file does not exist ($p{tarball})\n"
            unless -f $p{tarball};

        my ( $old_name, $version ) = $p{tarball} =~ /([\w-]+)(\.\d+)?\.tar/
            or die
            "Cannot determine workspace name and version from tarball name: $p{tarball}";
        $version ||= 0;

        my $new_name = $p{name} || $old_name;

        if ( $version > $MAX_VERSION ) {
            die "Cannot import a tarball with a version greater than $MAX_VERSION\n";
        }

        my $ws = Socialtext::Workspace->new( name => $new_name );
        if ( $ws && ! $p{overwrite} ) {
            die "Cannot restore $new_name workspace, it already exists.";
        }

        my $tarball = Cwd::abs_path( $p{tarball} );

        return bless {
            new_name  => $new_name,
            old_name  => $old_name,
            workspace => $ws,
            tarball   => $tarball,
            version   => $version,
            },
            $class;
    }
}

# I'd like to call this import() but then Perl calls it when the
# module is loaded.
sub import_workspace {
    my $self = shift;

    local $CWD = File::Temp::tempdir( CLEANUP => 1 );

    # XXX - I'm afraid to use Archive::Tar here cause it will load all
    # the data into memory, which could be enormous for workspaces
    # with many pages and attachments.
    system( 'tar', 'xzf', $self->{tarball} );

    # We have an exported workspace from before workspace info was in
    # the DBMS
    die 'Cannot import old format of workspace export'
        if -d "workspace/$self->{old_name}";

    my @users = $self->_import_users();

    $self->_create_workspace();

    $self->_import_data_dirs();

    $self->_fixup_page_symlinks();

    $self->_set_permissions();

    for my $u (@users) {
        $self->{workspace}->add_user(
            user => $u->[0],
            role => Socialtext::Role->new( name => $u->[1] ),
        );
    }
}

sub _create_workspace {
    my $self = shift;

    return if $self->{workspace};

    my $info = $self->_load_yaml( $self->_workspace_info_file() );
    my $creator = Socialtext::User->new( username => $info->{creator_username} );
    $creator ||= Socialtext::User->SystemUser();

    my $account = Socialtext::Account->new( name => $info->{account_name} );
    $account ||= Socialtext::Account->create( name => $info->{account_name} );

    my %create;
    for my $c (
        grep { $_ ne 'logo_uri' }
        map { $_->name } Socialtext::Workspace->columns
        ) {
        $create{$c} = $info->{$c}
            if exists $info->{$c};
    }
    $create{name} = $self->{new_name};

    my $ws = Socialtext::Workspace->create(
        %create,
        created_by_user_id => $creator->user_id,
        account_id         => $account->account_id,
        skip_default_pages => 1,
    );

    if ( $info->{logo_filename} ) {
        open my $fh, '<', $info->{logo_filename}
            or die "Cannot read $info->{logo_filename}: $!";
        $ws->set_logo_from_filehandle(
            filehandle => $fh,
            filename   => $info->{logo_filename},
        );
    }
    elsif ( $info->{logo_uri} ) {
        $ws->set_logo_from_uri( uri => $info->{logo_uri} );
    }

    $self->{workspace} = $ws;
}

sub _workspace_info_file { $_[0]->{old_name} . '-info.yaml' }

sub _load_yaml {
    my $self = shift;
    my $file = shift;

    my $mode = $self->{version} >= 1 ? '<:utf8' : '<';

    open my $fh, $mode, $file
        or die "Cannot read $file: $!";

    my $yaml = do { local $/; <$fh> };
    if ( $self->{version} < 1 ) {
        my $decoder = Encode::Guess->guess($yaml);
        $yaml = ref $decoder
            ? $decoder->decode($yaml)
            : Encode::decode( 'utf8', $yaml );
    }

    return YAML::Load($yaml);
}

sub _import_data_dirs {
    my $self = shift;
    my $data_root = Socialtext::AppConfig->data_root_dir();
    for my $dir (qw(plugin user data)) {
        my $src = Socialtext::File::catdir( $dir, $self->{old_name} );
        my $dest = Socialtext::File::catdir( $data_root, $dir, $self->{new_name} );
        Socialtext::File::Copy::Recursive::dircopy( $src, $dest )
            or die "Could not copy $src to $dest: $!\n";
    }
}

sub _fixup_page_symlinks {
    my $self = shift;

    File::Find::find(
        {
            no_chdir => 1,
            wanted   => sub {
                return unless -l $File::Find::name;

                my $target = readlink $File::Find::name;

                unlink $File::Find::name
                    or die "Cannot unlink $File::Find::name: $!";

                my $abs_target = Socialtext::File::catfile(
                    File::Basename::dirname($File::Find::name),
                    File::Basename::basename($target) );

                symlink $abs_target => $File::Find::name
                    or die
                    "Cannot symlink $abs_target => $File::Find::name: $!";
                }
        },
        Socialtext::Paths::page_data_directory( $self->{workspace}->name() )
    );
}

sub _set_permissions {
    my $self = shift;

    my $perms = $self->_load_yaml( $self->_permissions_file() );

    my $schema = Socialtext::Schema->Load();

    # REVIEW - almost identical to the core of
    # Socialtext::Workspace->set_permissions but just enough
    # different that it's hard to think of a good way to unify
    # them.
    my $wrp_table     = $schema->table('WorkspaceRolePermission');
    my $current_perms = $wrp_table->rows_where(
        where => [
            $wrp_table->column('workspace_id'),
            '=', $self->{workspace}->workspace_id
        ],
    );

    eval {
        $schema->begin_work();

        # XXX - Alzabo is lame and does not provide table-level
        # update and delete, which really needs to be corrected in
        # a near-future release.
        while ( my $wrp = $current_perms->next ) {
            $wrp->delete;
        }

        for my $p (@$perms) {
            $wrp_table->insert(
                values => {
                    workspace_id => $self->{workspace}->workspace_id,
                    role_id      =>
                        Socialtext::Role->new( name => $p->{role_name} )
                        ->role_id,
                    permission_id => Socialtext::Permission->new(
                        name => $p->{permission_name}
                        )->permission_id,
                },
            );
        }

        $schema->commit();
    };

    if ( my $e = $@ ) {
        $schema->rollback();
        rethrow_exception($e);
    }
}

sub _permissions_file { $_[0]->{old_name} . '-permissions.yaml' }

sub _import_users {
    my $self = shift;

    my $users = $self->_load_yaml( $self->_users_file() );

    my @cols = Socialtext::User->minimal_interface;
    my @users;
    for my $info (@$users) {
        my $user = Socialtext::User->new( 
            email_address => $info->{email_address} );
        $user ||= $self->_create_user( $info, \@cols );

        push @users, [ $user, $info->{role_name} ];
    }

    return @users;
}

sub _users_file { $_[0]->{old_name} . '-users.yaml' }

sub _create_user {
    my $self = shift;
    my $info = shift;
    my $cols = shift;

    my $creator
        = Socialtext::User->new( username => $info->{creator_username} );
    $creator ||= Socialtext::User->SystemUser();

    my %create;
    for my $c (@$cols) {
        $create{$c} = $info->{$c}
            if exists $info->{$c};
    }

    return Socialtext::User->create(
        %create,
        created_by_user_id => $creator->user_id,
        no_crypt           => 1,
    );
}


1;

__END__

