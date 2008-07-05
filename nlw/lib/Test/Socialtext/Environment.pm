# @COPYRIGHT@
package Test::Socialtext::Environment;
use strict;
use warnings;

use Cwd;
use lib Cwd::abs_path('./lib');

use base 'Socialtext::Base';

use Class::Field qw( field );
use File::chdir;
use File::Path;
use Socialtext::Workspace;
use Test::More;
use Test::Socialtext::Fixture;

field 'root_dir';
field 'base_dir';
field 'ports_start_at' => 30000;
# skip_cache implies three things: don't create the cache, don't extract from
# the cache, and always create the environment from scratch
field 'skip_cache' => 0;
field 'verbose';
field 'wiki_url_base';
field 'fixtures' => [];
field 'fixture_objects' => [];
field 'nlw_dir';

my $Self;

# NLW directory for the current branch, under which tests are run.
my $nlw_dir = $ENV{ST_CURRENT}  ? "$ENV{ST_CURRENT}/nlw"
            : $ENV{ST_SRC_BASE} ? "$ENV{ST_SRC_BASE}/current/nlw"
            : $CWD;

# A place to keep mains so they aren't garbage collected.
my @RememberedMains;

sub instance {
    my $class = shift;

    return $Self ||= $class->new(@_);
}

sub CreateEnvironment {
    shift->instance( @_ );
}

sub new {
    my $class = shift;

    my $self = $class->SUPER::new(
        nlw_dir  => $nlw_dir,
        root_dir => "$nlw_dir/t/tmp",
        base_dir => "$nlw_dir/t/tmp/root",

        # set by Module::Build for Test::Harness ...
        verbose => $ENV{TEST_VERBOSE},
        @_,
    );

    $self->_init_fixtures;
    $self->_set_url;
    $self->_clean_filesystem;
    $self->_create_test_environment;

    return $self;
}

sub _init_fixtures {
    my $self = shift;
    foreach my $name (@{$self->fixtures}) {
        Test::More::diag("Using fixture '$name'.") if $self->verbose;
        push @{ $self->fixture_objects },
          Test::Socialtext::Fixture->new( name => $name, env => $self );
    }
}

sub _set_url {
    my $self = shift;
    my $hostname = `hostname`;
    chomp($hostname);
    my $main_port = ( $self->ports_start_at ) + $>;
    $self->wiki_url_base( "http://$hostname:" . $main_port );
}

sub _clean_filesystem {
    my $self = shift;
    # Using File::Path::rmtree seems to generate warnings along the
    # lines of "Can't remove directory
    # /home/testrunner/livetests-trunk-nlw/t/tmp/root/plugin
    # (Directory not empty) at Test/Socialtext/Environment.pm line XX"
    #
    # We should be sure to not remove things like Apache config or pid
    # files here, or else things like NLW_LIVE_DANGEROUSLY cannot work
    #
    system( 'rm', '-rf', $self->base_dir );
    # clear out the ceqlotron's queue
    File::Path::rmtree($self->root_dir . '/ceq');
}

sub _make_fixtures_current {
    my $self = shift;
    foreach my $fixture (@{$self->fixture_objects}) {
        if ($self->skip_cache) {
            $fixture->generate;
        } else {
            $fixture->make_cache_current;
        }
    }
}

sub _maybe_decache {
    my $self = shift;
    unless ($self->skip_cache) {
        foreach my $fixture (@{$self->fixture_objects}) {
            $fixture->decache;
        }
    }
}

sub _create_test_environment {
    my $self = shift;
    -d $self->root_dir or mkdir $self->root_dir or die $self->root_dir . ": $!";

    # Ensure these directories are created in a dev-env / test environment.
    for my $subdir (qw(docroot storage)) {
        unless ( -d ( $self->base_dir . "/" . $subdir ) ) {
            File::Path::mkpath( $self->base_dir . "/" . $subdir, 0, 0775 );
        }
    }

    $self->_make_fixtures_current;
    $self->_maybe_decache;
}

sub hub_for_workspace {
    my $self = shift;
    my $name = shift || die "no name provided to hub_for_workspace";
    my $username = shift || 'devnull1@socialtext.com';
    my $ws = ref $name ? $name : Socialtext::Workspace->new( name => $name )
        or die "No such workspace: $name";

    my $main = Socialtext->new()->debug();
    my $hub  = $main->load_hub(
        current_workspace => $ws,
        current_user      => Socialtext::User->new( username => $username ),
    );

    $hub->registry->load;

    push @RememberedMains, $main;

    return $hub;
}


1;

