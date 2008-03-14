package Test::Socialtext::Bootstrap::OpenLDAP;
# @COPYRIGHT@

use strict;
use warnings;
use Class::Field qw(field);
use IO::Socket;
use Net::LDAP;
use Net::LDAP::LDIF;
use POSIX qw(:sys_wait_h);
use File::Path qw(mkpath rmtree);
use File::Spec;
use Time::HiRes qw(sleep);
use Test::Socialtext::Environment;
use Socialtext::LDAP::Config;

# XXX: these should be treated as "read-only" fields after instantiation
field 'host';
field 'port';
field 'base_dn';
field 'root_dn';
field 'root_pw';
field 'requires_auth';
field 'datadir';
field 'logfile';
field 'slapd';
field 'schemadir';
field 'moduledir';
field 'conffile';

my %ports = (
    ldap    => 389,
    ldaps   => 636,     # XXX: unused, but put in for completeness
    );

sub verbose {
    print STDERR "$_[0]\n" if ($ENV{TEST_VERBOSE});
}

sub new {
    my ($class, %config) = @_;
    my $env = Test::Socialtext::Environment->instance();

    # extract parameters
    my $port = $config{port} || _autodetect_port();
    my $self = {
        # generic parameters; could be factored to common base class
        host            => $config{host}            || 'localhost',
        port            => $port,
        base_dn         => $config{base_dn}         || 'dc=example,dc=com',
        root_dn         => $config{root_dn}         || 'cn=Manager,dc=example,dc=com',
        root_pw         => $config{root_pw}         || 'its-a-secret',
        requires_auth   => $config{requires_auth}   || 0,
        # openldap specific parameters
        datadir         => $config{datadir}         || File::Spec->catdir($env->root_dir(),'ldap',$port),
        logfile         => $config{logfile}         || File::Spec->catfile($env->root_dir(),'log',"ldap-$port.log"),
        slapd           => $config{slapd}           || _autodetect_slapd(),
        schemadir       => $config{schemadir}       || _autodetect_schema_dir(),
        moduledir       => $config{moduledir}       || _autodetect_module_dir(),
        };
    bless $self, $class;
    $self->conffile( File::Spec->catfile($self->datadir(), 'slapd.conf') );

    # start OpenLDAP
    $self->setup() or return;
    $self->start() or return;

    # return newly created object
    return $self;
}

sub _autodetect_port {
    my %args = @_;

    # attempts to auto-detect an empty port that we can listen on.
    #
    # calculated as:
    #   <ports_start_at> + <user-id> + <ldap-port>
    # and increments by 1000 each time we find that the port is already busy
    # and that someone else is listening on it.
    verbose( "# finding empty port to run OpenLDAP on" );
    my $attempts = 0;
    while ($attempts < 10) {
        my $port = Test::Socialtext::Environment->instance->ports_start_at()
                 + $ports{'ldap'}
                 + $<
                 + ($attempts * 1000);

        # see if anyone is listening on this port
        my $socket = IO::Socket::INET->new(
            Proto       => 'tcp',
            LocalPort   => $port,
            Listen      => SOMAXCONN,
            Reuse       => 1,
            );
        if ($socket) {
            verbose( "# ... using port $port" );
            return $port;
        }

        # busy, try next port
        $attempts ++;
    }
    die "unable to find empty/available port for OpenLDAP";
}

my $slapd;
sub _autodetect_slapd {
    unless ($slapd) {
        # attempts to auto-detect the path to the "slapd" binary on the system
        #
        # throws a FATAL exception if we're unable to find it
        foreach my $path (qw(/usr/sbin /usr/local/sbin)) {
            my $bin = File::Spec->catfile( $path, 'slapd' );
            if (-e $bin and -x $bin) {
                verbose( "# auto-detected slapd: $bin" );
                $slapd = $bin;
                return $slapd;
            }
        }
        die "unable to find executable 'slapd' binary\n";
    }
    return $slapd;
}

my $schema_dir;
sub _autodetect_schema_dir {
    unless ($schema_dir) {
        # attempts to auto-detect the path to the "schema" directory for the
        # installed OpenLDAP
        #
        # throws a FATAL exception if we're unable to find it
        foreach my $path (qw(/etc/ldap/schema /usr/local/etc/ldap/schema)) {
            my $file = File::Spec->catfile( $path, 'openldap.schema' );
            if (-e $file) {
                verbose( "# auto-detected OpenLDAP schema dir: $path" );
                $schema_dir = $path;
                return $schema_dir;
            }
        }
        die "unable to find OpenLDAP schema directory\n";
    }
    return $schema_dir;
}

my $module_dir;
sub _autodetect_module_dir {
    unless ($module_dir) {
        # attempts to auto-detect the path to the directory that OpenLDAP
        # dynamic modules are located in
        #
        # throws a FATAL exception if we're unable to find it
        foreach my $path (qw(/usr/lib/ldap /usr/local/lib/ldap)) {
            my $file = File::Spec->catfile( $path, 'back_bdb.so' );
            if (-e $file) {
                verbose( "# auto-detected OpenLDAP module dir: $path" );
                $module_dir = $path;
                return $module_dir;
            }
        }
        die "unable to find OpenLDAP dynamic module directory\n";
    }
    return $module_dir;
}

BEGIN {
    # if we're unable to auto-detect OpenLDAP, -ALL- of our tests should be
    # skipped (as opposed to failed); we don't want to impose restrictions on
    # developers that they've got to have OpenLDAP installed in order to run
    # the test suites.
    eval {
        _autodetect_slapd();
        _autodetect_schema_dir();
        _autodetect_module_dir();
    };
    if ($@) {
        require Test::Builder;
        Test::Builder->new->skip_all( "OpenLDAP not detected: $@" );
    }
};

sub DESTROY {
    my $self = shift;
    # shut down and cleanup after ourselves
    $self->stop();
    $self->teardown();
}

sub start {
    my $self = shift;
    return if $self->running();
    verbose( "# starting OpenLDAP" );

    # start OpenLDAP
    my @args = (
        '-f'    => $self->conffile(),
        '-d'    => 1,
        '-h'    => "ldap://$self->{host}:$self->{port}",
        );
    my $pid;
    unless ($pid = fork()) {
        die "fork: $!" unless defined $pid;

        # set up logging; we run slapd in debug mode and it doesn't detach
        open STDERR, ">$self->{logfile}";
        open STDOUT, '>&STDERR';
        close STDIN;

        # fire up slapd
        exec( $self->{slapd}, @args ) or die "cannot exec slapd @args\n\t$!";
    }

    # give OpenLDAP some time to start up or die off
    #
    # When running w/Devel::Cover, this takes a LOT longer than normal, so
    # rather than just sleeping an arbitrary amount of time we'll keep an eye
    # on it and wait for it to either (a) die off, or (b) respond to an
    # inbound connection.
    my $counter = 120;   # 40 x 0.25s = 20s
    while ($counter-- > 0) {
        # stop checking if we see the process die
        my $child = waitpid( -1, WNOHANG );
        last if ($child > 0);
        # stop checking if we can connect
        my $socket = IO::Socket::INET->new(
            Proto       => 'tcp',
            PeerHost    => $self->host(),
            PeerPort    => $self->port(),
            Timeout     => 0,
            );
        last if ($socket);
        sleep( 0.25 );
    }

    # make sure that OpenLDAP is running
    unless ($self->running($pid)) {
        warn "# unable to start OpenLDAP!";
        return;
    }
    $self->{pid} = $pid;
}

sub stop {
    my $self = shift;
    if ($self->running()) {
        # kill running OpenLDAP server, and give it some time to die off
        kill( 15, $self->{pid} );
        my $counter = 40;   # 40 x 0.25s = 10s
        while ($counter-- > 0) {
            my $child = waitpid( $self->{pid}, WNOHANG );
            last if ($child > 0);
            sleep( 0.25 );
        }
        # make sure that it died off
        if ($self->running()) {
            # didn't; KILL IT NOW!
            warn "# forcefully killing OpenLDAP server (pid=$self->{pid})";
            kill( 9, $self->{pid} );
        }
    }
    delete $self->{pid};
}

sub running {
    my ($self, $pid) = @_;
    $pid ||= $self->{pid};
    return ($pid and kill(0,$pid));
}

sub save_ldap_config {
    my ($self, $filename) = @_;
    # create ST::LDAP::Config object based on our config
    my $config = Socialtext::LDAP::Config->new(
        backend     => 'OpenLDAP',
        host        => $self->host(),
        port        => $self->port(),
        base        => $self->base_dn(),
        attr_map    => {
            user_id         => 'dn',
            username        => 'cn',
            email_address   => 'mail',
            first_name      => 'givenName',
            last_name       => 'sn',
            },
        );
    $self->root_dn() && $config->bind_user( $self->root_dn() );
    $self->root_pw() && $config->bind_password( $self->root_pw() );
    # save the config out to the specified file
    $config->save( $filename );
}

sub setup {
    my $self = shift;

    # create data directory
    unless (-d $self->datadir()) {
        my $path = $self->datadir();
        verbose( "# creating OpenLDAP data directory: $path" );
        mkpath( $path, 0, 0755 ) or die "can't create '$path'; $!";
    }

    # rebuild config file
    my $conf = $self->conffile();
    unless (-f $conf) {
        my $env  = Test::Socialtext::Environment->instance();
        verbose( "# writing slapd.conf" );
        my $requires_auth = $self->{requires_auth} ? 'disallow bind_anon' : '';

        open( my $fout, ">$conf" ) || die "can't write '$conf'; $!";
        print $fout <<END_SLAPD_CONF;
# include libraries
modulepath $self->{moduledir}
moduleload back_bdb
# include core OpenLDAP schemas
include $self->{schemadir}/core.schema
include $self->{schemadir}/cosine.schema
include $self->{schemadir}/inetorgperson.schema
# logging
pidfile $env->{root_dir}/run/slapd-$self->{port}.pid
argsfile $env->{root_dir}/run/slapd-$self->{port}.args
# database
database bdb
suffix "$self->{base_dn}"
rootdn "$self->{root_dn}"
rootpw "$self->{root_pw}"
directory "$self->{datadir}"
# auth requirements
$requires_auth
END_SLAPD_CONF
        close $fout;
    }

    return 1;
}

sub teardown {
    my $self = shift;
    if ((-d $self->datadir()) and ($self->datadir() ne '/')) {
        verbose( "# removing OpenLDAP data directory" );
        rmtree( $self->datadir() );
    }
}

sub add {
    my ($self, $ldif_filename) = @_;
    my $cb = sub {
        my ($ldap, $entry) = @_;
        my $mesg = $ldap->add( $entry );
        if ($mesg->code()) {
            warn "# error adding from LDIF:\n"
               . "#\t" . $mesg->code() . ': ' . $mesg->error() . "\n";
            $entry->dump(*STDERR);
            return;
        }
        return 1;
    };
    return $self->_ldif_update( $ldif_filename, $cb );
}

sub remove {
    my ($self, $ldif_filename) = @_;
    my $cb = sub {
        my ($ldap, $entry) = @_;
        my $mesg = $ldap->delete( $entry->dn() );
        if ($mesg->code()) {
            warn "# error removing from LDIF:\n"
               . "#\t" . $mesg->code() . ': ' . $mesg->error() . "\n";
            $entry->dump(*STDERR);
            return;
        }
        return 1;
    };
    return $self->_ldif_update( $ldif_filename, $cb );
}

sub _ldif_update {
    my ($self, $filename, $callback) = @_;

    # Open up the LDIF file
    my $ldif = Net::LDAP::LDIF->new( $filename, 'r', onerror => undef );
    unless ($ldif) {
        warn "# unable to read LDIF file: $filename\n";
        return;
    }

    # Connect to the LDAP server
    my $ldap = Net::LDAP->new( $self->host(), port => $self->port() );
    unless ($ldap) {
        warn "# unable to connect to LDAP server\n";
        return;
    }

    my $mesg = $ldap->bind( $self->root_dn(), password => $self->root_pw() );
    if ($mesg->code()) {
        warn "# unable to bind to LDAP server\n";
        warn "#\t" . $mesg->code() . ': ' . $mesg->error() . "\n";
        return;
    }

    # Feed the data to the LDAP server
    while (not $ldif->eof()) {
        my $entry = $ldif->read_entry();
        return unless $callback->( $ldap, $entry );
    }
    $ldif->done();

    return 1;
}

1;

=head1 NAME

Test::Socialtext::Bootstrap::OpenLDAP - Bootstrap OpenLDAP instances

=head1 SYNOPSIS

  # bootstrap needs to be loaded -BEFORE- planning your tests (we'll skip_all
  # if we can't auto-detect a suitable OpenLDAP installation).
  use Test::Socialtext::Bootstrap::OpenLDAP;
  use Test::Socialtext tests => ...

  # bootstrap with default config
  $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new();

  # bootstrap with custom config
  $openldap = Test::Socialtext::Bootstrap::OpenLDAP->new(%config);

  # stop/restart the OpenLDAP instance
  $openldap->stop();
  $openldap->start();

  # manipulate contents of LDAP directory
  $openldap->add($ldif_filename);
  $openldap->remove($ldif_filename);

  # write OpenLDAP configuration to ST::LDAP::Config file
  $yamlfile = File::Spec->catfile(
      Socialtext::AppConfig->config_dir(),
      'ldap.yaml'
      );
  $openldap->save_ldap_config($yamlfile);

  # query config of the OpenLDAP instance
  #
  # realistically, you should only ever need a minimum of these (if
  # any); if you're finding that you're calling these repeatedly,
  # we've missed something in creating this bootstrap harness.
  $host             = $openldap->host();
  $port             = $openldap->port();
  $base_dn          = $openldap->base_dn();
  $root_dn          = $openldap->root_dn();
  $root_pw          = $openldap->root_pw();
  $requires_auth    = $openldap->requires_auth();
  $datadir          = $openldap->datadir();
  $logfile          = $openldap->logfile();
  $slapd            = $openldap->slapd();
  $schemadir        = $openldap->schemadir();
  $moduledir        = $openldap->moduledir();
  $conffile         = $openldap->conffile();

=head1 DESCRIPTION

C<Test::Socialtext::Bootstrap::OpenLDAP> implements an interface that allows
for you to bootstrap (possibly multiple) OpenLDAP instances during testing.

Thinking is that although Unit Tests are nice, nothing really beats testing
against a real/live LDAP directory.  Doing that requires our being able to fire
up a copy of OpenLDAP, add some data to it, and then run our tests against it.
Testing may even require that we stop/restart the LDAP directory mid-test in
order to simulate failed/down connections.

Thus, C<Test::Socialtext::Bootstrap::OpenLDAP>, a simple bootstrap harness
around OpenLDAP.

B<NOTE:> if we're unable to auto-detect an installed copy of OpenLDAP, B<all>
of the tests are skipped automatically.  We didn't want to impose restrictions
on developers that they had to have OpenLDAP installed, so we simply
C<skip_all>.  This does mean, however, that you need to C<use> this bootstrap
I<before> you set up your test plan!

=head1 METHODS

=over

=item B<new(%config)>

Fires up a new OpenLDAP instance based on the provided C<%config>.

Defaults are available (or auto-detected) for B<all> of the configuration
options.  You should be able to conveniently fire up multiple OpenLDAP
instances just by going:

  $ldap_one   = Test::Socialtext::Bootstrap::OpenLDAP->new();
  $ldap_two   = Test::Socialtext::Bootstrap::OpenLDAP->new();
  $ldap_three = Test::Socialtext::Bootstrap::OpenLDAP->new();
  ...

If you really feel the need to customize an OpenLDAP instance, though, the
following configuration options are supported:

=over

=item host

Specifies the hostname or IP address that we should be using.

=item port

Specifies the port number that we should be using.

=item base_dn

Specifies the Base DN for the LDAP directory.

=item root_dn

Specifies the DN of the root/admin user for the LDAP directory.

=item root_pw

Specifies the password for the root/admin user for the LDAP directory.

=item requires_auth

Specifies whether or not the OpenLDAP server I<requires> that the connection be
authenticated (if required, anonymous binds will fail).

=item datadir

Specifies the data directory that is used for all of the files that OpenLDAP
requires or will place to disk.  This directory will be auto-created and
auto-removed for you.

=item logfile

Specifies the path to a logfile that OpenLDAP will use for writing its debug
output to.

=item slapd

Specifies the full path to the F<slapd> binary to use.

=item schemadir

Specifies the full path to the installed OpenLDAP schema directory.

=item moduledir

Specifies the full path to the OpenLDAP dynamic back-end modules.

=back

=item B<start()>

Starts the OpenLDAP instance.  Is called automatically by C<new()>, so you only
need to call this if you've explicitly shut down the server and want to restart
it.

=item B<stop()>

Stops the OpenLDAP instance.

=item B<running($pid)>

Checks to see if the OpenLDAP instance is running.  An optional C<$pid> may be
provided if you wish to check if some other process is running; by default we
use the PID of our OpenLDAP instance.

=item B<save_ldap_config($filename)>

Saves the current configuration of the OpenLDAP instance as YAML to the given
filename.  Configuration is saved in a format suitable for use by
C<Socialtext::LDAP::Config>.

Useful for bootstrapping OpenLDAP, then creating the YAML file to go along with
it for the rest of your testing.

=item B<setup()>

Sets up the data directory and configuration file required by OpenLDAP.  Called
automatically by C<new()>; its B<not> necessary for you to ever call this
method.

=item B<teardown()>

Cleans up after ourselves, removing the data directory entirely when we're done.
Called automatically by C<DESTROY()>; its B<not> necessary for you to ever call
this method.

=item B<add($ldif_filename)>

Adds items to the OpenLDAP instance from the LDIF in the specified file.
Returns true if we're able to add all of the LDIF entries successfully, false
on error.

=item B<remove($ldif_filename)>

Removes items from the OpenLDAP instance based on their entries in the given
LDIF file.  Returns true if we're able to remove all of the LDIF entries
successfully, false on error.

=item B<host()>

Returns the IP address that the OpenLDAP server is running on.

=item B<port()>

Returns the port number that the OpenLDAP server is running on.

=item B<base_dn()>

Returns the "Base DN" for the OpenLDAP instance, specifying the root node in
this LDAP directory.

=item B<root_dn()>

Returns the "Root DN" for the OpenLDAP instance; the username for the
root/admin user.

=item B<root_pw()>

Returns the "Root Password" for the OpenLDAP instance.

=item B<requires_auth()>

Returns a flag stating whether or not the OpenLDAP instance I<requires> that
all connections be authenticated.  If true, then anonymous binds will be
refused.

=item B<datadir()>

Returns the path to the data directory that is being used by this OpenLDAP
instance.

=item B<logfile()>

Returns the path to the logfile that is being written to by this OpenLDAP
instance.

=item B<slapd()>

Returns the full path to the F<slapd> executable that is used.

=item B<schemadir()>

Returns the path to the directory that contains the installed OpenLDAP schema
files.

=item B<moduledir()>

Returns the path to the directory that contains the installed OpenLDAP dynamic
modules.

=item B<conffile()>

Returns the full path to the F<slapd.conf> file used by our OpenLDAP instance.

=back

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
