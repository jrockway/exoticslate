package Socialtext::Workspace::Importer;
# @COPYRIGHT@

use strict;
use warnings;

use Encode::Guess qw( ascii iso-8859-1 utf8 );
use File::chdir;
use Cwd;
use Socialtext::File::Copy::Recursive ();
use Readonly;
use Socialtext::SQL qw(sql_commit sql_execute sql_begin_work sql_rollback );
use Socialtext::Validate qw( validate FILE_TYPE BOOLEAN_TYPE SCALAR_TYPE );
use Socialtext::AppConfig;
use Socialtext::Workspace;
use Socialtext::Exceptions qw/rethrow_exception/;
use Socialtext::Search::AbstractFactory;
use Socialtext::Log qw(st_log);
use Socialtext::Timer;
use Socialtext::System qw/shell_run/;
use Socialtext::Page::TablePopulator;
use YAML ();

# This should stay in sync with $EXPORT_VERSION in ST::Workspace.
Readonly my $MAX_VERSION => 1;

{
    Readonly my $spec => {
        name      => SCALAR_TYPE(optional => 1),
        tarball   => FILE_TYPE,
        overwrite => BOOLEAN_TYPE( default => 0 ),
        noindex   => BOOLEAN_TYPE( default => 0 ),
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

        my $new_name = lc( $p{name} || $old_name );

        if ( $version > $MAX_VERSION ) {
            die "Cannot import a tarball with a version greater than $MAX_VERSION\n";
        }

        my $ws = Socialtext::Workspace->new( name => $new_name );
        if ( $ws && ! $p{overwrite} ) {
            die "Cannot restore $new_name workspace, it already exists.\n";
        }

        my $tarball = Cwd::abs_path( $p{tarball} );

        return bless {
            new_name  => $new_name,
            old_name  => $old_name,
            workspace => $ws,
            tarball   => $tarball,
            version   => $version,
            noindex   => $p{noindex},
            },
            $class;
    }
}

# I'd like to call this import() but then Perl calls it when the
# module is loaded.
sub import_workspace {
    my $self = shift;
    my $timer = Socialtext::Timer->new;

    eval {
        my $old_cwd = getcwd();
        local $CWD = File::Temp::tempdir( CLEANUP => 1 );
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
        $self->_populate_db_metadata();

        for my $u (@users) {
            $self->{workspace}->add_user(
                user => $u->[0],
                role => Socialtext::Role->new( name => $u->[1] ),
            );
        }

        unless ($self->{noindex}) {
            chdir( $old_cwd );
            Socialtext::Search::AbstractFactory->GetFactory->create_indexer(
                $self->{workspace}->name )
                ->index_workspace( $self->{workspace}->name );
        }

        st_log()
            ->info( 'IMPORT,WORKSPACE,workspace:'
                . $self->{new_name} . '('
                . $self->{workspace}->workspace_id
                . '),[' . $timer->elapsed . ']');
    };
    if (my $err = $@) {
        if ($self->{workspace}) {
            eval { $self->{workspace}->delete };
            warn $@ if $@;
        }
        die "Error importing workspace $self->{new_name}: $err";
    }
    return $self->{workspace};
}

sub _create_workspace {
    my $self = shift;

    return if $self->{workspace};

    my $info = $self->_load_yaml( $self->_workspace_info_file() );
    my $creator = Socialtext::User->new( username => $info->{creator_username} );
    $creator ||= Socialtext::User->SystemUser();

    my $account = Socialtext::Account->new( name => $info->{account_name} );
    $account ||= Socialtext::Account->create( name => $info->{account_name} );

    my $ws = Socialtext::Workspace->create(
        title => $info->{title},
        name => $self->{new_name},
        created_by_user_id => $creator->user_id,
        account_id         => $account->account_id,
        skip_default_pages => 1,
    );

    my %update;
    my @to_update = grep { $_ ne 'logo_uri' 
            and $_ ne 'name' 
            and $_ ne 'created_by_user_id' 
            and $_ ne 'account_id' }
        map { $_ } @Socialtext::Workspace::COLUMNS;
    for my $c (@to_update) {
        $update{$c} = $info->{$c}
            if exists $info->{$c};
    }

    $ws->update( %update );

    if ( my $logo_filename = $info->{logo_filename} ) {
        $ws->set_logo_from_file(
            filename   => $logo_filename,
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

    eval {
        sql_begin_work();

        sql_execute(
            'DELETE FROM "WorkspaceRolePermission" WHERE workspace_id = ?',
            $self->{workspace}->workspace_id,
        );

        my $sql =
            'INSERT INTO "WorkspaceRolePermission" (workspace_id, role_id, permission_id) VALUES (?,?,?)';
        for my $p (@$perms) {
            sql_execute(
                $sql,
                $self->{workspace}->workspace_id,
                Socialtext::Role->new(name => $p->{role_name})->role_id,
                Socialtext::Permission->new(name => $p->{permission_name})->permission_id,
            );
        }

        sql_commit();
    };

    if ( my $e = $@ ) {
        sql_rollback();
        rethrow_exception($e);
    }
}

sub _populate_db_metadata {
    my $self = shift;

    Socialtext::Timer->Continue('populate_db');
    my $populator = Socialtext::Page::TablePopulator->new(
        workspace_name => $self->{new_name} );
    $populator->populate;
    Socialtext::Timer->Pause('populate_db');
}

sub _permissions_file { $_[0]->{old_name} . '-permissions.yaml' }

sub _import_users {
    my $self = shift;

    my $users = $self->_load_yaml( $self->_users_file() );

    my @users;
    for my $info (@$users) {
        delete $info->{primary_account_id};
        my $user = Socialtext::User->new( username => $info->{username} )
                || Socialtext::User->new( email_address => $info->{email_address} )
                || Socialtext::User->Create_user_from_hash( $info );
        push @users, [ $user, $info->{role_name} ];
    }

    return @users;
}

sub _users_file { $_[0]->{old_name} . '-users.yaml' }

1;

__END__
