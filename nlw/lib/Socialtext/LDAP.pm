package Socialtext::LDAP;
# @COPYRIGHT@

use strict;
use warnings;
use Socialtext::AppConfig;
use Socialtext::Log qw(st_log);
use Socialtext::LDAP::Config;
use File::Spec;

sub new {
    my ($class, $conn_name) = @_;

    # get configuration object for this connection
    my $config = $conn_name
                    ? Socialtext::LDAP->config($conn_name)
                    : Socialtext::LDAP->default_config();
    return unless ($config);

    # connect to the LDAP server
    return Socialtext::LDAP->connect($config);
}

sub default_config {
    return Socialtext::LDAP->config('Default');
}

sub config {
    my ($class, $conn_name) = @_;
    my $yaml_file = Socialtext::LDAP->config_filename($conn_name);
    return Socialtext::LDAP::Config->load( $yaml_file );
}

sub config_filename {
    my ($class, $conn_name) = @_;
    my $yaml_file = File::Spec->catfile(
        Socialtext::AppConfig->config_dir(),
        'ldap.yaml',
        );
    return $yaml_file;
}

sub connect {
    my ($class, $config) = @_;
    my $conn = _get_connection( $config );
    return unless ($conn);
    return $conn->bind();
}

sub available {
    # only a single LDAP configuration available right now
    # XXX: should really do a config scan instead of being hardcoded
    return 'Default';
}

sub authenticate {
    my ($class, $dn, $pass) = @_;

    my $config = Socialtext::LDAP->default_config();
    return unless ($config);

    my $conn   = _get_connection( $config );
    return unless ($conn);

    return $conn->authenticate($dn, $pass);
}

sub _get_connection {
    my $config = shift;

    # get plug-in module which implements the back-end
    my $backend = _get_class( $config->backend() );
    eval "use $backend";
    if ($@) {
        st_log->error( "ST::LDAP: unable to load LDAP back-end plug-in '$backend'; $@" );
        return;
    }

    # instantiate the back-end
    my $conn = eval { $backend->new( $config ) };
    if ($@) {
        st_log->error( "ST::LDAP; unable to instantiate LDAP back-end plug-in '$backend'; $@" );
        return;
    }
    return $conn;
}

sub _get_class {
    my $backend = shift;
    # use default back-end unless one was provided
    $backend ||= 'Base';
    # return class used to implement back-end
    my $ldap_class = 'Socialtext::LDAP::' . $backend;
    return $ldap_class;
}

1;

=head1 NAME

Socialtext::LDAP - LDAP connection factory

=head1 SYNOPSIS

  use Socialtext::LDAP;

  # connect to default LDAP server
  $ldap = Socialtext::LDAP->new();
  $ldap = Socialtext::LDAP->new('Default');

  # get default LDAP configuration
  $config = Socialtext::LDAP->default_config();

  # get configuration for a specific LDAP server
  $config = Socialtext::LDAP->config('Default');

  # get configuration file name for a specific LDAP server
  $filename = Socialtext::LDAP->config_filename('Default');

  # connect to LDAP server using given configuration
  $ldap = Socialtext::LDAP->connect($config);

  # list the known/configured LDAP connections
  @conns = Socialtext::LDAP->available();

=head1 DESCRIPTION

C<Socialtext::LDAP> implements a factory for LDAP connections.

=head1 METHODS

=over

=item B<Socialtext::LDAP-E<gt>new($conn_name)>

Creates a new LDAP connection, for the named LDAP connection.  If no LDAP
connection name is provided, a default LDAP connection will be made.

B<NOTE:> in the current implementation, there is I<only one> configuration; the
default configuration; doesn't matter what C<$conn_name> is, you'll always get
back a connection to the default LDAP server.

=item B<Socialtext::LDAP-E<gt>default_config()>

Retrieves the LDAP configuration for the "Default" LDAP connection, returning
it back to the caller as a C<Socialtext::LDAP::Config> object.

=item B<Socialtext::LDAP-E<gt>config($conn_name)>

Retrieves the configuration for a named LDAP connection, returning it back to
the caller as a C<Socialtext::LDAP::Config> object.

B<NOTE:> in the current implementation, there is I<only one> configuration; the
default configuration; doesn't matter what C<$conn_name> is, you'll always get
back the default LDAP configuration file.

=item B<Socialtext::LDAP-E<gt>config_filename($conn_name)>

Returns the name of the YAML configuration file used for the named LDAP connection.

B<NOTE:> in the current implementation, there is I<only one> configuration; the
default configuration; doesn't matter what C<$conn_name> is, you'll always get
back the default LDAP configuration file.

=item B<Socialtext::LDAP-E<gt>connect($config)>

Connects to an LDAP server, using the configuration in the provided
C<Socialtext::LDAP::Config> object.

=item B<Socialtext::LDAP-E<gt>available()>

Returns a list of known configured LDAP connections.

=item B<Socialtext::LDAP-E<gt>authenticate($dn, $pass)>

Attempts to authenticate against the LDAP server using the provided
distinguishedName and password.  Returns true if authentication is successful,
returning false otherwise.

=back

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
