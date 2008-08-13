# @COPYRIGHT@
package Test::Socialtext::Fixture;

# Inspired by Ruby on Rails' fixtures.
# See http://api.rubyonrails.com/classes/Fixtures.html

use strict;
use warnings;
use Carp qw( confess );
use DateTime;
use File::Basename ();
use File::chdir;
use File::Slurp qw(slurp write_file);
use File::Spec;
use Socialtext::ApacheDaemon;
use Socialtext::Build qw( get_build_setting );
use File::Path qw/mkpath rmtree/;
use FindBin;
use Socialtext::Schema;
use Socialtext::Hub;
use Socialtext::Pages;
use Socialtext::User;
use Socialtext::AppConfig;

my $DefaultUsername = 'devnull1@socialtext.com';


sub new {
    my $class = shift;
    my $self = {@_};

    croak("Need to specify an environment") unless exists $self->{env};
    croak("Need to specify a name") unless exists $self->{name};
    bless $self, $class;

    $self->_init;

    return $self;
}

sub _init {
    my $self = shift;
    $self->{fixtures} = [];

    my $dir = $self->dir;

    $self->_generate_base_config();

    require Socialtext::Account;
    require Socialtext::Paths;
    require Socialtext::User;
    require Socialtext::Workspace;

    if (-f "$dir/fixture.yaml") {
        require YAML;

        $self->set_config(YAML::LoadFile("$dir/fixture.yaml"))
            or die "Could not load " . $self->name . "/fixture.yaml: $!";
        foreach my $sub_name (@{$self->config->{fixtures}}) {
            push @{ $self->fixtures },
                Test::Socialtext::Fixture->new( name => $sub_name, env => $self->env );
        }
    }
    else {
        $self->set_config({});
    }
}

# XXX - this is a bit gross and unlike the other fixture bits, but
# it's a prereq for all other fixtures, though not necessarily for all
# tests.
my $BaseConfigGenerated;
sub _generate_base_config {
    return if $BaseConfigGenerated;
    my $self = shift;

    my $env               = $self->env;

    my $testing = $ENV{HARNESS_ACTIVE} ? '--testing' : '';
    my $gen_config = $env->nlw_dir . '/dev-bin/gen-config';
    my $apache_proxy    = get_build_setting('apache-proxy');
    my $socialtext_open = get_build_setting('socialtext-open');

    _system_or_die(
        $gen_config,
        '--quiet',
        '--root',           $env->root_dir,
        '--ports-start-at', $env->ports_start_at,
        '--apache-proxy=' . $apache_proxy,
        '--socialtext-open=' . $socialtext_open,
        '--dev=0',    # Don't create the files in ~/.nlw
        $testing,
    );

    # Put the schemas in place
    my $schema_dir = $env->root_dir . '/etc/socialtext/db';
    rmtree $schema_dir;
    mkpath $schema_dir;
    _system_or_die("cp " . $env->nlw_dir . "/etc/socialtext/db/* $schema_dir");

    local $ENV{ST_TEST_SKIP_DB_DUMP} = 1;
    my $s = Socialtext::Schema->new( verbose => 1);
    $s->recreate(no_dump => 1);

    my $db_name = Socialtext::AppConfig->db_name();
    _system_or_die("psql -f " . $env->nlw_dir . "/etc/socialtext/db/dev.sql $db_name");

    $BaseConfigGenerated = 1;
}

sub is_current {
    my $self = shift;
    my $dir = $self->dir;

    if (-x "$dir/is-current") {
        return ! (system "$dir/is-current");
    }

    return 0;
}

sub generate {
    my $self = shift;

    unless ( $self->is_current() ) {
        $self->_generate_subfixtures;
        $self->_generate_workspaces;
        $self->_run_custom_generator;
    }
}

sub _run_custom_generator {
    my $self = shift;
    my $dir = $self->dir;
    my $env = $self->env;

    if (-r "$dir/generate") {
        local $ENV{NLW_DIR} = $env->nlw_dir;
        local $ENV{NLW_ROOT_DIR} = $env->root_dir;
        local $ENV{NLW_STARTING_PORT} = $env->ports_start_at;

        (system "$dir/generate") == 0
            or die $self->name . "/generate exit ", $? >> 8;
    }
}

sub _create_user {
    my $self = shift;
    my %p = @_;

    my $user = Socialtext::User->new( username => $p{username} );
    $user ||= Socialtext::User->create(
        username        => $p{username},
        email_address   => $p{username},
        password        => 'd3vnu11l',
        is_business_admin  => $p{is_business_admin},
        is_technical_admin => $p{is_technical_admin},
    );

    return $user;
}

sub _generate_subfixtures {
    my $self = shift;

    foreach my $name (@{$self->config->{fixtures}}) {
        Test::Socialtext::Fixture->new(name => $name, env => $self->env)->generate();
    }
}

my %PermsForName = (
    public          => 'public',
    'auth-to-edit'  => 'public-authenticate-to-edit',
);
sub _generate_workspaces {
    my $self = shift;

    return unless $self->config->{workspaces};

    my $creator = $self->_create_user(
        username           => $DefaultUsername,
        is_business_admin  => 1,
        is_technical_admin => 1,
    );
    my $account_id = Socialtext::Account->Socialtext()->account_id();

    # Why do we _always_ generate the help workspace?
    $self->_generate_help_workspace( $creator, "help-en" );

    print STDERR "# workspaces: " if $self->env->verbose;
    while ( my ( $name, $spec ) = each %{ $self->config->{workspaces} } ) {
        print STDERR "$name... " if $self->env->verbose;
        if ( $name =~ /help/ ) {
            $self->_generate_help_workspace( $creator, $name );
            next;
        }

	my $title = ucfirst($name) . ' Wiki';

	if( defined $spec->{title} ) {
	    $title = $spec->{title};
	}

        my $ws = Socialtext::Workspace->create(
            name               => $name,
            title              => $title,
            account_id         => $account_id,
            created_by_user_id => $creator->user_id(),
            account_id         => Socialtext::Account->Socialtext()->account_id,
            ($spec->{no_pages} ? (skip_default_pages => 1) : ())
        );

        my $perms = $PermsForName{ $ws->name } || 'member-only';
	if( defined( $spec->{permission_set_name} )) {
	    $perms = $spec->{permission_set_name};
	}

        $ws->permissions->set( set_name => $perms );

        # Add extra users in the roles specified.
        while ( my ( $role, $users ) = each %{ $spec->{extra_users} } ) {
            $self->_add_user( $ws, $_, $role ) for @$users;
        }

        $self->_create_extra_pages($ws) if $spec->{extra_pages};
        $self->_create_ordered_pages($ws) if $spec->{ordered_pages};
        $self->_activate_impersonate_permission($ws)
            if $spec->{admin_can_impersonate};
    }

    print STDERR "done!\n" if $self->env->verbose;
}

sub _add_user {
    my $self = shift;
    my $ws = shift;
    my $username = shift;
    my $rolename = shift;

    $ws->add_user(
        user => $self->_create_user( username => $username ),
        role => Socialtext::Role->new( name => $rolename ),
    );
}

sub _activate_impersonate_permission {
    my $self = shift;
    my $workspace = shift;

    $workspace->permissions->add(
        permission => Socialtext::Permission->new( name => 'impersonate' ),
        role => Socialtext::Role->WorkspaceAdmin(),
    );
}

sub _generate_help_workspace {
    my $self = shift;
    my $user = shift;
    my $ws_name = shift || 'help-en';
    my $tarball = $self->env->nlw_dir . "/share/l10n/help/$ws_name.tar.gz";

    # Workspace already exists.
    return if Socialtext::Workspace->new( name => $ws_name );

    # Load up the workspace from a previous export.
    my $st_admin = $self->env->nlw_dir . '/bin/st-admin';
    _system_or_die(
        $st_admin,
        'import-workspace',
        '--tarball',    $tarball,
        '--overwrite',
    );
    my $ws = Socialtext::Workspace->new( name => $ws_name );
    $ws ->add_user(
        user => $user,
        role => Socialtext::Role->WorkspaceAdmin(),
    );
}

sub _unlink_existing_pages {
    my $self = shift;
    my $ws = shift;
    my $workspace_name = $ws->name;

    my $user = Socialtext::User->SystemUser();
    my $hub = Socialtext::Hub->new(
        current_workspace => $ws,
        current_user => $user,
    );
    my @pages = Socialtext::Pages->new(hub => $hub)->all;
    for my $p (@pages) {
        $p->delete(user => $user);
    }

    $self->_clean_workspace_ceqlotron_tasks($workspace_name);
}

# remove the ceqlotron jobs we don't want
sub _clean_workspace_ceqlotron_tasks {
    my $self           = shift;
    my $workspace_name = shift;

    require Socialtext::Ceqlotron;
    Socialtext::Ceqlotron::ensure_queue_directory();
    Socialtext::Ceqlotron::ensure_lock_file();

    my $program = $self->env->nlw_dir . '/bin/ceq-rm';
    system($program, $workspace_name) and die "$program failed: $!";
}

sub _create_ordered_pages {
    my $self = shift;
    my $ws = shift;

    $self->_unlink_existing_pages($ws);

    my $workspace_name = $ws->name;

    my $hub = $self->env->hub_for_workspace($ws);

    my $category_count = 1;

    # prepare the recent changes data
    my $date = DateTime->now;
    $date->subtract( seconds => 120 );
    for my $number (qw(one two three four five six)) {
        my $category = $category_count++ % 2;
        $category = "category $category";

        # We set the dates to ensure a repeatable sort order
        my $page = Socialtext::Page->new( hub => $hub )->create(
            title      => "$workspace_name page $number",
            content    => "$number content",
            date       => $date,
            categories => [$category],
            creator    => $hub->current_user,
        );
        $date->add( seconds => 5 );
    }
}

sub _create_extra_pages {
    my $self = shift;
    my $ws = shift;

    my $hub = $self->env->hub_for_workspace($ws);
    my $xtra_pgs_dir = $self->env->nlw_dir . '/t/extra-pages';

    for my $file ( grep { -f && ! /(?:\.sw.|~)$/ } glob "$xtra_pgs_dir/*" ) {
        my $name = Encode::decode( 'utf8', File::Basename::basename( $file ) );
        $name =~ s{_SLASH_}{/}g;

        open my $fh, '<:utf8', $file
            or die "Cannot read $file: $!";
        my $content = File::Slurp::read_file($fh);

        Socialtext::Page->new( hub => $hub )->create(
            title   => $name,
            content => $content,
            date    => $self->_get_deterministic_date_for_page($name),
            creator => Socialtext::User->SystemUser(),
        );
    }

    $self->_create_extra_attachments($ws);
}

sub _get_deterministic_date_for_page {
    my $self = shift;
    my $name  = shift;
    my $epoch = DateTime->now->epoch;

    $epoch -= $self->_hash_name_for_seconds_in_the_past($name);

    return DateTime->from_epoch( epoch => $epoch )
}

sub _hash_name_for_seconds_in_the_past {
    my $self = shift;
    my $name = shift;

    # We want some pages to stay at the top of RecentChanges for quick access:
    my @very_recents = split /\n/, <<'EOT';
FormattingTest
FormattingToDo
WikiwygFormattingToDo
WikiwygFormattingTest
Babel
Internationalization
<script>alert("pathological")</script>
EOT
    return 0 if grep { $_ eq $name } @very_recents;

    my $NUM_BUCKETS = 1000;
    my $x = 33;
    $x *= ord for split //, $name;
    $x %= $NUM_BUCKETS;

    my $OFFSET_TO_ACCOUNT_FOR_VERY_RECENTS = 60;
    my $SECONDS_CURVE_ROOT = exp(log(60*60*24)/$NUM_BUCKETS);
    return
        $OFFSET_TO_ACCOUNT_FOR_VERY_RECENTS
        + int(($SECONDS_CURVE_ROOT**$x)*$x);
}

sub _create_extra_attachments {
    my $self = shift;
    my $ws = shift;

    my $hub = $self->env->hub_for_workspace($ws);

    local $CWD = $self->env->nlw_dir . '/t/extra-attachments';
    for my $dir ( grep { -d && ! /\.svn/ } glob '*' ) {
        $hub->pages->current( $hub->pages->new_from_name( $dir ) );

        for my $file ( grep { -f } glob "$dir/*" ) {
            open my $fh, '<', $file
                or die "Cannot read $file: $!";

            $hub->attachments->create(
                fh     => $fh,
                embed  => 0,
                filename => $file,
                creator  => Socialtext::User->SystemUser(),
            );
        }
    }
}

sub _system_or_die {
    (system @_) == 0 or confess("Cannot execute @_: $!");
}

sub env { $_[0]->{env} }
sub name { $_[0]->{name} }
sub dir { $_[0]->env->nlw_dir . "/t/Fixtures/" . $_[0]->name }
sub config { $_[0]->{config} }
sub set_config { $_[0]->{config} = $_[1] }
sub fixtures { $_[0]->{fixtures} }

1;

__END__
