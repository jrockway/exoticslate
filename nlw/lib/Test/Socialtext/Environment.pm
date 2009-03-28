# @COPYRIGHT@
package Test::Socialtext::Environment;
use strict;
use warnings;

use Cwd;
use lib Cwd::abs_path('./lib');

use base 'Socialtext::Base';

use Carp;
use Class::Field qw( field );
use File::chdir;
use File::Path;
use Socialtext::Workspace;
use Socialtext::HTTP::Ports;
use Test::More;
use Test::Socialtext::Fixture;
use Test::Socialtext::User;

field 'root_dir';
field 'base_dir';
field 'verbose' => 1;
field 'wiki_url_base';
field 'fixtures' => [];
field 'fixture_objects' => [];
field 'nlw_dir';

# Live dangerously by default - Safety Third!
$ENV{NLW_LIVE_DANGEROUSLY} = 1;

my $Self;

# NLW directory for the current branch, under which tests are run.
my $nlw_dir;
foreach my $maybe (
        $ENV{ST_CURRENT} ? "$ENV{ST_CURRENT}/nlw" : (),
        $ENV{ST_SRC_BASE} ? "$ENV{ST_SRC_BASE}/current/nlw" : (),
        $CWD
        ) {
    if (-d $maybe) {
        $nlw_dir = $maybe;
        last;
    }
}
unless (-d $nlw_dir) {
    die "unable to detect nlw_dir!";
}

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

    # unless we're testing dangerously (and quickly), make sure that we clean
    # everything out before starting a new test.
    unless ($ENV{NLW_LIVE_DANGEROUSLY}) {
        unshift @{$self->{fixtures}}, 'clean';
    }

    $self->_clean_if_last_test_was_destructive;
    $self->_init_fixtures;
    $self->_set_url;
    $self->_make_fixtures_current;

    return $self;
}

sub _clean_if_last_test_was_destructive {
    my $self = shift;
    my $fixture = Test::Socialtext::Fixture->new( name => 'destructive', env => $self );
    if ($fixture->is_current) {
        Test::More::diag( "last test was destructive; cleaning everything out and starting fresh" );
        unshift @{$self->{fixtures}}, 'clean';
    }
}

sub _init_fixtures {
    my $self = shift;
    foreach my $name (@{$self->fixtures}) {
        Test::More::diag("Using fixture '$name'.") if $self->verbose;
        my $fixture = Test::Socialtext::Fixture->new( name => $name, env => $self );
        push @{$self->fixture_objects}, $fixture;

        if ($fixture->has_conflicts) {
            Test::More::diag("... fixture conflict detected; cleaning first") if $self->verbose;
            unshift @{$self->fixture_objects},
              Test::Socialtext::Fixture->new( name => 'clean', env => $self );
        }
    }
}

sub _set_url {
    my $self = shift;
    my $hostname = `hostname`;
    chomp($hostname);
    my $main_port = Socialtext::HTTP::Ports->http_port();
    $self->wiki_url_base( "http://$hostname:" . $main_port );
}

sub _make_fixtures_current {
    my $self = shift;
    foreach my $fixture (@{$self->fixture_objects}) {
        $fixture->generate;
    }
}

sub hub_for_workspace {
    my $self = shift;
    my $name = shift || die "no name provided to hub_for_workspace";
    my $username = shift || Test::Socialtext::User->test_username();
    my $ws = ref $name ? $name : Socialtext::Workspace->new( name => $name )
        or croak "No such workspace: $name";

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

