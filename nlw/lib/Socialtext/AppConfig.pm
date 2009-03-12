package Socialtext::AppConfig;
# @COPYRIGHT@
use strict;
use warnings;

use Config;
use Cwd ();
use File::Basename ();
use File::Spec ();
use File::Path qw/mkpath/;
use Sys::Hostname;
use Socialtext::Validate qw(
    validate validate_with
    SCALAR_TYPE BOOLEAN_TYPE
    NONNEGATIVE_INT_TYPE POSITIVE_INT_TYPE
    FILE_TYPE DIR_TYPE
    URI_TYPE SECURE_URI_TYPE EMAIL_TYPE
);
use User::pwent;
use YAML ();
use YAML::Dumper;
use Socialtext::Build qw( get_build_setting get_prefixed_dir );

# We capture this at load time and then will later check
# $Current_user->uid to see if the user _when the module was loaded_
# was root. We do not want to check $> later because under mod_perl
# this will change once Apache forks its children.
my $StartupUser = getpwuid($>);

my @obviously_not_human_users = qw( www-data wwwrun nobody daemon );
my %obviously_not_human_users = map {($_,1)} @obviously_not_human_users;

sub _startup_user_is_human_user {
    return 0 if $obviously_not_human_users{ $StartupUser->name };

    # XXX - This is Debian and OSX specific. I doubt there's a 100%
    # correct way of doing this, since people can do any crazy thing
    # on their systems they want, but it'd be nice to have this work
    # on any system that was compliant with its distro/OSs usre
    # numbering scheme.
    return 1 if $StartupUser->uid >= 500;

    return;
}

# Used _only_ for testing
sub _set_startup_user { shift; $StartupUser = getpwuid(shift) }

my %Options = _parse_pod_for_options();

sub _parse_pod_for_options {
    my $pm_file = $INC{'Socialtext/AppConfig.pm'};
    open my $fh, '<', $pm_file
        or die "Cannot read $pm_file: $!";

    my $file = do { local $/; <$fh> };

    my ($pod) = $file =~ m{
        =head1\ CONFIGURATION\ VARIABLES  # the start of the relevant section
         .+?                               # ignore the bit up to the first =head2
         (?=
           =head2)                         # don't eat this =head2, we
                                           # want it in the capture

         (.+)                              # the config variables
         (?:=head1|=cut)                   # this marks the end of the config variables
       }xs;

    my %opts;
    while ( $pod =~ m{\G
                     =head2\ (\w+)               # the variable name
                     (.+?)                       # the description
                     \s+
                     (?:                         # it can have a default, or be optional, but not both
                       (?:^Default:\s+(.+?)$)    # a default
                       |
                       (^Optional\.)             # or it's optional, but not both
                     )?                          # maybe it has neither
                     \s*
                     (?:^=for\ code\ default\s*=>\s* (.+?)$)? # the default is some subroutine
                     \s*
                     (?:^=for\ code\ type\s*=>\s*(.+?)$)      # the type, required
                     \s+
                    }gxsm ) {

        my ( $name, $desc, $default_string, $optional, $default_code, $type )
            = ( $1, $2, $3, $4, $5, $6 );

        # This means the regex ate through the beginning of one or
        # more config variables following the current one until it
        # found a type.
        #
        # REVIEW - if the last item is missing a type, this won't
        # catch it, the regex will just stop matching.
        if ( $default_string && ( $default_string =~ /=head2/ ) ) {
            die "The POD for $name is missing a type\n";
        }

        $opts{$name} = { description => $desc };
        if ( defined $default_string ) {
            # print " $default_string -";
            $opts{$name}{default} = $default_string;
        }
        elsif ( defined $default_code ) {
            $opts{$name}{default} = eval $default_code;
            die $@ if $@;
            # print " $default_code == $opts{$name}{default} -";
        }
        elsif ( defined $optional ) {
            # print " optional -";
            $opts{$name}{optional} = 1;
        }
        # print "\n";
    }

    return %opts;
}

sub is_default {
    my $self = shift;
    my $name = shift;
    return $self->$name eq $Options{$name}{default};
}

sub _default_data_root {
    return ( _startup_user_is_human_user()
             ? File::Spec->catdir( _user_root(), 'root' )
             : get_prefixed_dir("webroot"));
}

sub _default_code_base {
    return (
        _startup_user_is_human_user()
        ? File::Spec->catdir( _user_checkout_dir(), 'share' )
        : get_prefixed_dir("sharedir")
    );
}

{
    # hold the initial CWD of when we we started, so we can fix up relative
    # paths here if needed.
    my $initial_cwd = Cwd::cwd();

    sub _user_checkout_dir {
        my $base = File::Basename::dirname(__FILE__);

        my $dir = Cwd::abs_path( 
            File::Spec->catdir( $ENV{ST_SRC_BASE}, 'current', 'nlw' )
        );

        return $dir if defined $dir && -d $dir;

        return Cwd::abs_path(
            File::Spec->catdir(
                (
                    File::Spec->file_name_is_absolute($base)
                    ? ()
                    : $initial_cwd
                ),
                $base,
                File::Spec->updir,
                File::Spec->updir
            )
        );
    }
}

sub _default_template_compile_dir {
    return File::Spec->catdir( _cache_root_dir(), 'tt2' );
}

sub _default_formatter_cache_dir {
    return File::Spec->catdir( _cache_root_dir(), 'formatter' );
}

sub _default_change_event_queue_dir {
    my $root =
        $ENV{HARNESS_ACTIVE}
            ? _user_root()
            : get_prefixed_dir('spooldir');
    return File::Spec->catdir( $root, 'ceq' )
}

sub _cache_root_dir {
    return ( _startup_user_is_human_user()
             ? File::Spec->catdir( _user_root(), 'cache' )
             : get_prefixed_dir('cachedir'));
}

sub _default_pid_file_dir {
    return ( _startup_user_is_human_user()
             ? File::Spec->catfile( _user_root(), 'run' )
             : get_prefixed_dir('piddir'));
}

sub _default_admin_script {
    my $script = File::Spec->catfile( bin_path(), 'st-admin' );
    return ( ( -x $script ) ? $script : "/usr/local/bin/st-admin" );
}

=head2 bin_path()

Returns the location that executable scripts should be stored at.

=cut

sub bin_path {
    if ( _startup_user_is_human_user() ) {
        return File::Spec->catfile( _user_checkout_dir(), 'bin' );
    }
    return $Config{installscript};
}

sub _default_db_name {
    return 'NLW' unless _startup_user_is_human_user();

    my $name = 'NLW_' . $StartupUser->name;
    $name .= '_testing' if $ENV{HARNESS_ACTIVE};

    return $name;
}

sub _default_schema_name { 'socialtext' }

sub _default_db_user {
    return ( _startup_user_is_human_user()
             ? $StartupUser->name
             : 'nlw' )
}

sub _default_locale {
    return get_build_setting('default-locale') || 'en';
}

sub _default_workspace {
    my $locale = _default_locale();
    if ($locale eq 'en') {
        return 'help';
    } else {
        return lc("help-$locale");
    }
}

sub _user_root {
    if ( $ENV{HARNESS_ACTIVE} ) {
        my $dir;

        # Under mod_perl, Apache will already have chdir'd to /
        if ( $ENV{MOD_PERL} ) {
            $dir = Apache->server_root_relative();
            $dir =~ s{(.+t/tmp).*}{$1};
        }
        else {
            $dir = Cwd::abs_path(
                File::Spec->catdir( _user_checkout_dir(), 't', 'tmp' )
            );
        }

        die "Cannot find the user root with the HARNESS_ACTIVE env var set\n"
            unless $dir;

        # Untaint this so tests pass with tainting on.
        # REVIEW: This untainting should be more stringent.
        ($dir) = $dir =~ /(.+)/;

        return $dir;
    }
    else {
        return File::Spec->catdir( $StartupUser->dir, '.nlw' );
    }
}

sub Options { keys %Options }

# XXX be smarter about reloading here. We don't want to check
# every single time.
for my $f ( keys %Options ) {
    next if __PACKAGE__->can($f);

    my $sub = sub {
        return $1
            if exists $ENV{NLW_APPCONFIG}
            and $ENV{NLW_APPCONFIG} =~ /(?:^|,)$f=(.*?)(?:$|,)/;

        my $self = shift;
        $self = $self->instance()
            unless ref $self;

        $self->_reload_if_modified;
        return $self->{config}{$f};
    };
    no strict 'refs';
    *{$f} = $sub;
}

my $Self;
sub instance {
    my $class = shift;

    return $Self || $class->new();
}

sub new {
    my $class = shift;
    my %p = @_;

    # REVIEW:
    #
    # The goal here is to allow gen-config to call Socialtext::AppConfig->new
    # to load the old file Socialtext::AppConfig->new() without making that
    # the new singleton instance, since it's full of bogus
    # junk. That's why we don't save it as a singleton if file is
    # provide.
    #
    # However, this module's own _reload_if_modified calls new() with
    # a file parameter, but in that case we _do_ want to save the new
    # object as the singleton instance, thus the singleton
    # parameter. This is all pretty gross, and could use some review.
    # The unit tests also use _singleton for testing.
    my $save_singleton = $p{file} ? 0 : 1;
    $save_singleton ||= $p{_singleton};

    my $default_config_file = _find_config_file() || '';
    %p = validate(
        @_, {
            file       => FILE_TYPE( default => $default_config_file ),
            strict     => BOOLEAN_TYPE( default => 1 ),
            _singleton => BOOLEAN_TYPE( default => 0 ),
        },
    );

    my $config_from_file =
        $p{file} && -f $p{file} ? YAML::LoadFile( $p{file} ) : {};

    my $real_config = validate_with(
        params      => ( $config_from_file || {} ),
        spec        => \%Options,
        allow_extra => $p{strict},
    );

    my $self = bless {}, $class;

    $self->{original_data} = $config_from_file;
    $self->{config} = $real_config;

    $self->{file} = $p{file};
    $self->{last_mod_time} = time;
    $self->{last_size}     = (-s $p{file}) || 0;

    $Self = $self
        if $save_singleton;

    return $self;
}

sub file {
    my $self = shift;
    $self = $self->instance()
        unless ref $self;

    return $self->{file}
}

# really just provided to help with testing
sub _last_mod_time { $_[0]->instance->{last_mod_time} }

sub _reload_if_modified {
    my $self = shift;

    return unless -f $self->{file};

    # We check size as well as last mod time because at least in the
    # tests, the file can be created, read, and modified in less than
    # one second.  The size check doesn't require an extra system call
    # so it's cheap to do.  This still isn't 100% accurate, but unless
    # we can get sub-second resolutions out of stat(), it's as good as
    # it gets.
    my $mod_time = ( stat $self->{file} )[9];
    my $size     = -s _;

    return
        if $mod_time <= $self->{last_mod_time}
        && $size == $self->{last_size};

    my $reload = (ref $self)->new(
        file       => $self->{file},
        # REVIEW - bleah, this is gross
        _singleton => ( $Self and $Self == $self ),
    );

    %$self = %$reload;
}

sub _find_config_dirs {
    my @dirs;

    if ( !$ENV{HARNESS_ACTIVE} ) {
        push @dirs, '/etc/socialtext';
        if ( _startup_user_is_human_user() ) {
            unshift @dirs, $StartupUser->dir . '/.nlw/etc/socialtext';
        }
    }
    else {
        my $test_dir = _user_root() . '/etc/socialtext';
        push @dirs, $test_dir;
        unless (-d $test_dir) {
            mkpath $test_dir or die "Can't mkpath $test_dir: $!";
        }
    }

    return @dirs;
}

sub config_dir {
    my @dirs = _find_config_dirs();
    foreach my $dir (@dirs) {
        return $dir if -d $dir;
    }
}

sub _find_config_file {
    my @dirs = _find_config_dirs();
    my @files = map { $_ . "/socialtext.conf" } @dirs;

    unshift @files, $ENV{NLW_CONFIG}
        if ( defined $ENV{NLW_CONFIG} and length $ENV{NLW_CONFIG} );

    foreach my $f (@files) {
        return $f if -r $f;
    }
}

sub db_connect_params {
    my $self = shift;
    $self = $self->instance()
        unless ref $self;

    my %connect_params = ( 
        db_name => $self->db_name(),
        schema_name => $self->schema_name(),
    );

    for my $field (qw( db_user db_password db_host db_port )) {
        next unless defined $self->$field();

        ( my $k = $field ) =~ s/^db_//;

        $connect_params{$k} = $self->$field();
    }

    return %connect_params;
}

sub support_address_as_mailto {
    my $addr = __PACKAGE__->support_address;
    return qq{<a href="mailto:$addr">$addr</a>};
}

sub shortcuts_file {
    my $self = shift;
    $self = $self->instance()
        unless ref $self;

    return $self->{config}{shortcuts_file}
        if defined $self->{config}{shortcuts_file};

    if ( $self->{file} ) {
        my $file = File::Spec->catfile(
            File::Basename::dirname( $self->{file} ),
            'shortcuts.yaml',
        );

        if ( -f $file ) {
            $self->{config}{shortcuts_file} = $file;
            return $file;
        }
    }
}

sub MAC_secret {
    my $self = shift;
    $self = $self->instance()
        unless ref $self;

    return $self->{config}{MAC_secret}
        if $self->{config}{MAC_secret};

    # REVIEW - is there a better way to distinguish between a real
    # installation and a developer installation?
    die "Cannot generate a MAC secret once app has started except in dev environments"
        unless $StartupUser->dir =~ m{^(?:/home|/Users)};

    return $StartupUser->name . ' needs a better secret';
}

sub has_value {
    my $self = shift;
    $self = $self->instance()
        unless ref $self;

    my $key = shift;

    return exists $self->{config}{$key};
}

sub is_appliance {
    return 1 if $ENV{NLW_IS_APPLIANCE};

    my $self = shift;
    $self = $self->instance()
        unless ref $self;

    $self->{is_appliance} ||=
        -e '/etc/socialtext/appliance.conf'
        ? 1
        : 0;

    return $self->{is_appliance};
}

sub set {
    my $self = shift;
    $self = $self->instance()
        unless ref $self;

    my %p = @_;

    my %spec = map { $Options{$_} ? ( $_ => $Options{$_} ) : () } keys %p;
    %p = validate( @_, \%spec );

    while ( my ( $k, $v ) = each %p ) {
        $self->{config}{$k} = $v;
        $self->{original_data}{$k} = $v;
    }
}

sub write {
    my $self = shift;
    $self = $self->instance()
        unless ref $self;

    my %p = validate( @_, { file => SCALAR_TYPE( optional => 1 ) } );

    my $file = $p{file} || $self->{file};

    die "Cannot call write() on an object without a file unless an output file is specified.\n"
        unless $file;

    open my $fh, '>', $file
        or die "Cannot write to $file: $!";

    my $time = scalar localtime();
    print $fh <<"EOF";
# This file was generated by Socialtext::AppConfig. Changes to the settings
# in this file will be preserved, but changes to comments will not be.

# Generated: $time

EOF

    for my $k ( sort { lc $a cmp lc $b } keys %Options ) {
        my $desc = $Options{$k}{description};
        $desc =~ s/^/\# /mg;

        if ( $Options{$k}{optional} ) {
            $desc .= "\n# Optional\n";
        }
        elsif ( $Options{$k}{default} ) {
            $desc .= "\n# Defaults to $Options{$k}{default}\n";
        }

        print $fh $desc;
        print $fh "#\n";

        my $dumper = YAML::Dumper->new;
        $dumper->use_header(0);
        $dumper->use_block(1);

        if ( exists $self->{original_data}{$k} ) {
            print $fh $dumper->dump( { $k => $self->{original_data}{$k} } );
        }
        else {
            if ( $Options{$k}{optional} ) {
                # YAML will want to use either ~ for undef or '', but
                # either reads kind of funny as a default.
                print $fh "# $k:\n";
            }
            else {
                my $default = $Options{$k}{default};

                my $dumped = $dumper->dump( { $k => $default } );
                $dumped =~ s/^/# /gm;

                print $fh "$dumped\n";
            }
        }

        print $fh "\n";
    }
}

# NOTE: AppConfig.pm is a dependency of ST/l10n.pm, so we cannot rely on
# l10n's loc() at compile time.  But we still must call loc() so that 
# the strings can be captured by gettext.pl
#
# So, l10n.pm will over-ride this method on load to be the correct method.
sub loc { shift }

1;

__END__

=head1 NAME

Socialtext::AppConfig - Application-wide configuration for NLW

=head1 SYNOPSIS

  use Socialtext::AppConfig;

  if ( Socialtext::AppConfig->is_default('user_factories') ) { ... }

  Socialtext::AppConfig->set( web_services_proxy => 'https://proxy.example.com/' );
  Socialtext::AppConfig->write();

=head1 DESCRIPTION

This module provides access to the application config file for NLW. If
this file does not exist, this module will try to provide reasonable
defaults for all config variables, at least when running in a
developer environment.

=head1 USAGE

For general usage, you can simply call all of the config variable
methods as class methods on the C<Socialtext::AppConfig> class. However, it
is also possible to explicitly create an C<Socialtext::AppConfig> object if
you want. The main reason this would be useful would be to explicitly
override the file to be used for configuration information.

=head2 Configuration File Locations

C<Socialtext::AppConfig> tries to find a config file in several
locations. If the current user is not root, and we are not running
under the Perl test harness, the module looks in
F<~/.nlw/etc/socialtext/socialtext.conf> first. After that, it tries
F</etc/socialtext/socialtext.conf>.

However, you can override this by setting the C<NLW_CONFIG>
environment variable. If this is set, then the module looks for the
file specified in that variable first.

Finally, you can call C<< Socialtext::AppConfig->new() >> and pass a "file"
parameter to the constructor to force it to use that file, whether or
not it exists. This is done primarily to make it possible to write a
config file to a new a file.

=head2 config_dir

We provide the directory where our configuration file can be found as
a means to allow other configuration files to be retrieved at the same
location.

=head1 CONFIGURATION VARIABLES

The following configuration variables can be set in the config
file. All variables either have a reasonable default or are optional.

Some of the defaults depend on whether the application was started as
root, or whether it is running under the Perl test harness. The
assumption is that if the app started as root (when C<Socialtext::AppConfig>
was I<loaded>), then it must be a production environment. This means
that to trigger this behavior under mod_perl, the module must be
loaded during server startup, before Apache forks and changes its user ID.

All of these variables are available by calling them as class methods
on C<Socialtext::AppConfig>, for example
C<< Socialtext::AppConfig->status_message_file >>.

=head2 status_message_file

The path to a file containing a status message to be shown on all the
pages.

Optional.

=for code type => FILE_TYPE

=head2 login_message_file

The path to a file containing a message to shown on the login screen.

Optional.

=for code type => FILE_TYPE

=head2 shortcuts_file

The file containing WAFL shortcut definitions. By default, this module
tries to find a file named F<shortcuts.yaml> in the same directory as
the config file.

Optional.

=for code type => FILE_TYPE

=head2 data_root_dir

The root directory for NLW data files.

If the startup user was root, defaults to F</var/www/socialtext>. If
the user was not root, it defaults to F<~/.nlw/root> or F<t/tmp/root>
under the Perl test harness.

=for code default => _default_data_root()

=for code type => DIR_TYPE

=head2 code_base

The directory under which various files needed by NLW are installed,
such as templates, javascript, images, etc.

If the startup user was root, this defaults to F</usr/share/nlw>,
otherwise it defaults the current directory at startup.

=for code default => _default_code_base()

=for code type => DIR_TYPE

=head2 template_compile_dir

The directory to use for caching compiled TT2 templates.

If the startup user was root, this defaults to
F</var/cache/socialtext/tt2>. Under the test harness it defaults to
F<t/tmp/cache/tt2>, otherwise F<~/.nlw/cache/tt2>.

Optional.

=for code default => _default_template_compile_dir()

=for code type => SCALAR_TYPE

=head2 formatter_cache_dir

The directory to use for caching the parse tree for a page.

If the startup user was root, this defaults to
F</var/cache/socialtext/formatter>. Under the test harness it defaults
to F<t/tmp/cache/formatter>, otherwise F<~/.nlw/cache/formatter>.

=for code default => _default_formatter_cache_dir()

=for code type => SCALAR_TYPE

=head2 change_event_queue_dir

The directory where change events are stored.

=for code default => _default_change_event_queue_dir()

=for code type => SCALAR_TYPE

=head2 pid_file_dir

The directory where daemons for NLW should put pid files.

If the startup user was root, this defaults to F</var/run/socialtext>.
Under the test harness it defaults to F<t/tmp/rnu>, otherwise
F<~/.nlw/run>.

=for code default => _default_pid_file_dir()

=for code type => DIR_TYPE

=head2 admin_script

The location of the Socialtext command line admin script.

If the startup user was root, the default is
F</usr/local/bin/st-admin>, and for non-root users it is
F<./bin/st-admin>.

=for code default => _default_admin_script()

=for code type => FILE_TYPE

=head2 script_name

The name of the script used in NLW application URIs.

Default: index.cgi

=for code type => SCALAR_TYPE

=head2 ssl_port

The port on which NLW is listening for SSL connections.

Default: 443

=for code type => POSITIVE_INT_TYPE

=head2 ssl_only

NLW will only allow SSL access.

Default: 0

=for code type => BOOLEAN_TYPE

=head2 custom_http_port

Specifies NLW uses a non-standard HTTP port.  Requests to port 80
will be forwarded to this port.  0 means no custom port.

Default: 0

=for code type => POSITIVE_INT_TYPE

=head2 cookie_domain

The domain to be used for cookies set by NLW. If left, unset, this
defaults to the hostname for the virtual host serving NLW.

Optional.

=for code type => SCALAR_TYPE

=head2 web_services_proxy

The URI to a proxy to be used for web services (like Dashboard widgets, 
Google search, RSS feeds).

Optional.

=for code type => URI_TYPE

=head2 email_errors_to

An email address to which error messages will be sent. If not set, no
emails will be sent.

Optional.

=for code type => EMAIL_TYPE

=head2 support_address

The address to displayed in the app as the application support address.
The default is the value of --support-address supplied when configure
was run.

=for code default => get_build_setting('support-address')

=for code type => EMAIL_TYPE

=head2 web_hostname

The hostname used when generating fully-qualified URIs inside NLW.

Defaults to the system's hostname, as returned by
C<Sys::Hostname::hostname()>.

Optional.

=for code default => Sys::Hostname::hostname()

=for code type => SCALAR_TYPE

=head2 email_hostname

The hostname used when generating email addresses inside NLW.

Defaults to the system's hostname, as returned by
C<Sys::Hostname::hostname()>.

Optional.

=for code default => Sys::Hostname::hostname()

=for code type => SCALAR_TYPE

=head2 ceqlotron_synchronous

If this is true, this forces the Ceqlotron to dispatch tasks
synchronously one-at-a-time (without forking).

Default: 0

=for code type => BOOLEAN_TYPE

=head2 ceqlotron_max_concurrency

The maximum number of child processes the Ceqlotron will run in
parallel.

Default: 5

=for code type => POSITIVE_INT_TYPE

=head2 ceqlotron_period

The time, in seconds, betweens runs of the change event queue.

Default: 5

=for code type => NONNEGATIVE_INT_TYPE

=head2 did_you_know_title

The did you know title

=for code default => loc('Access a Community of Peers')

=for code type => SCALAR_TYPE

=head2 did_you_know_text

The did you know text

=for code default => loc('As a Socialtext customer, you have access to the <a href="http://www.socialtext.net/exchange/">Socialtext Customer Exchange</a>. It is where you can share tips and best practices with other Socialtext customers.')

=for code type => SCALAR_TYPE

=head2 MAC_secret

A secret used for seeding any digests generated by the app. This is
used for things like verifying user login cookies.

If the startup user was not root, then this variable is not required,
as it will be generated as needed. For production environments, this
must be set in the config file.

Optional.

=for code type => SCALAR_TYPE

=head2 technorati_key

The key to be used for Technorati searches (via WAFL).

Note that the default is Socialtext's key.

Default: 350218482ca294c73bb92bdcce1359c4

=for code type => SCALAR_TYPE

=head2 challenger

The challenge system for this installation, defaults to the NLW login system

Default: STLogin

=for code type => SCALAR_TYPE

=head2 credentials_extractors

The colon-separated list of drivers to use for extracting credentials from a
request.

Default: BasicAuth:Cookie:Guest

=for code type => SCALAR_TYPE

=head2 logout_redirect_uri

The URI that users are redirected to after they log out.

Default: /nlw/login.html

=for code type => SCALAR_TYPE

=head2 user_factories

The semicolon-separated list of drivers to use for user creation.

Default: Default

=for code type => SCALAR_TYPE

=head2 unauthorized_returns_forbidden

If this is true, then when a user is not authorized to perform an
action (like view a workspace), the server returns a forbidden (403)
error instead of sending them to the login screen.  Defaults to false.

Default: 0

=for code type => BOOLEAN_TYPE

=head2 custom_invite_screen

Use a different set of templates and actions for the invitation screen.

Optional.

=for code type => SCALAR_TYPE

=head2 db_name

The name of the database in the DBMS to which we connect.

If the startup user was root, this defaults to "NLW". Otherwise, this
defaults to "NLW_<username>_testing" under the test harness, and
"NLW_<username>" otherwise.

=for code default => _default_db_name()

=for code type => SCALAR_TYPE

=head2 schema_name

The name of the schema in the DBMS to which we connect.

=for code default => _default_schema_name()

=for code type => SCALAR_TYPE

=head2 db_user

The name of the to use when connecting to the DBMS.

If the startup user was root, this defaults to "nlw", otherwise it is
the current user's username.

=for code default => _default_db_user()

=for code type => SCALAR_TYPE

=head2 db_password

The password to use when connecting to the DBMS.

Optional.

=for code type => SCALAR_TYPE

=head2 db_host

The host to use when connecting to the DBMS. If not set, we do not
provide this when connecting, which for Postgres means we will connect
via a local Unix socket.

Optional.

=for code default => get_build_setting('db-host')

=for code type => SCALAR_TYPE

=head2 db_port

The post to use when connecting to the DBMS.

Optional.

=for code type => POSITIVE_INT_TYPE

=head2 enable_weblog_archive_sidebox

If this is true, the weblog archive sidebox is shown when viewing a
weblog. This will be removed as a configuration option once the box is
not so darn slow.

Default: 0

=for code type => BOOLEAN_TYPE

=head2 default_workspace

When a user logs into the system and the app does not know what
workspace they want, this is default workspace they are sent to.

=for code default => _default_workspace()

=for code type => SCALAR_TYPE

=head2 locale

The two letter country code for the locale of your Socialtext install.  This
usually defaults to English, but that can be changed at install time.

=for code default => _default_locale()

=for code type => SCALAR_TYPE

=head2 stats

A comma- or dot-delimited list of runtime statistics to keep track
of. Setting this to "ALL" turns on all statistics. Collecting these
statistics slows the application down.

Optional.

=for code type => BOOLEAN_TYPE

=head2 syslog_level

The minimum log level used for passing messages to syslog.

Default: warning

=for code type => SCALAR_TYPE

=head2 benchmark_mode

Set this to true tells NLW you are running benchmarks against
it. This tries to make developer environment act more like a
production environment, so the benchmarks are reflective of real
performance.

Default: 0

=for code type => BOOLEAN_TYPE

=head2 debug

Setting this to true turns on debugging output for NLW.

Default: 0

=for code type => BOOLEAN_TYPE

=head2 search_factory_class

This points the system at different fulltext search implementations.  See
L<Socialtext::Search::AbstractFactory> for more details.

Default: Socialtext::Search::KinoSearch::Factory

=for code type => SCALAR_TYPE

=head2 interwiki_search_set

This allows an administrator to establish a set of workspaces to be searched
as a default collection. Specified as a colon-separated list of workspace
names.

=for code default => '' 

=for code type => SCALAR_TYPE

=head2 reports_summary_email

Setting this causes the reports summary to be sent to the specified address.

Optional.

=for code type => SCALAR_TYPE

=head2 reports_skip_file

Set this to a file containing workspaces names that should not be included
in view/edit stats reporting.

Optional.

=for code type => SCALAR_TYPE

=head2 self_registration

Set this to false to prevent users from registering user accounts.

Default: 1

=for code type => BOOLEAN_TYPE

=head1 OTHER METHODS

In addition to the methods available for each configuration variable,
the following methods are available.

=head2 Socialtext::AppConfig->instance()

Returns an instance of the C<Socialtext::AppConfig> singleton. This does not
accept any parameters.

=head2 Socialtext::AppConfig->new()

This method explicitly creates a new object, as opposed to re-using a
singleton. Creating an object in this way does not change the
singleton value. The object's methods are the same as those which can
be called on the C<Socialtext::AppConfig> class, excluding constructors.

This method accepts the following parameters:

=over 4

=item * file

The location of the config file. This file does not have to exist, in
which case you can call C<write()> later to create it.

See L<Configuration File Locations> for details on how
C<Socialtext::AppConfig> will look for a file if none is specified.

=item * strict

When this is false, then an existing config file may continue invalid
configuration variables, and the constructor will not throw an
exception. This is useful when upgrading between NLW versions, and you
want to read a config file created with an earlier version of NLW.

By default, this is true, and invalid configuration variables cause an
exception.

=back

=head2 Socialtext::AppConfig->Options()

Returns a list of valid configuration variable names.

=head2 Socialtext::AppConfig->db_connect_params()

Returns a hash of parameters for connecting to the DBMS suitable for
use by your code. The hash returned will always have a "db_name"
key, the name of the schema to which we connect. It may also have any
of "user", "password", "host", and "port" if these are set in the
configuration object. If they are not set, the key is not present.

=head2 Socialtext::AppConfig->support_address_as_mailto

Returns the support_address as a link inside an C<< <a> >> tag.

=head2 Socialtext::AppConfig->has_value($key)

Given a key, this method returns true if that key has a value, either
from the config file or a default. This can be used to check if an
optional variable has been set.

=head2 Socialtext::AppConfig->is_default($key)

Given a key, this method returns true if that key is set to the default
value.

=head2 Socialtext::AppConfig->is_appliance

Returns true if NLW is running on an appliance.

=head2 Socialtext::AppConfig->set( key => $value, ... )

Given a list of keys and values, this method sets the relevant
configuration variables based on the values given. The keys must be
valid configuration variables.

=head2 Socialtext::AppConfig->write( [ file => $file ] )

By default, this method writes the configuration to the file from
which the configuration information was loaded. This can be overridden
by passing in a "file" parameter.  If the object was created without
reading from a file and non is specified, then this method will throw
an exception.

If you want to create a new file from scratch, you can create an
object explicitly and pass it a "file" parameter:

  my $config = Socialtext::AppConfig->new( file => $file );
  $config->set( ... );
  $config->write();

Writing a config file does not preserve comments in the file.

=head1 ENVIRONMENT

The C<NLW_APPCONFIG> environment variable can be set to a series of
comma-separated key=value pairs to override the config file. For
example:

  export NLW_APPCONFIG='db_user=one-eye,db_password=fnord'

This sets the value of db_user to "one-eye" and db_password to
"fnord".

There is currently no method to escape commas.  Add it if you need it.

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2005-2006 Socialtext, Inc., All Rights Reserved.

=cut
