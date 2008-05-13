package Socialtext::LDAP::Config;
# @COPYRIGHT@

use strict;
use warnings;
use Class::Field qw(field);
use File::Spec;
use Time::HiRes qw(gettimeofday);
use YAML;
use Socialtext::AppConfig;
use Socialtext::Log qw(st_log);

field 'id';
field 'name';
field 'backend';
field 'base';
field 'host';
field 'port';
field 'bind_user';
field 'bind_password';
field 'filter';
field 'follow_referrals' => 1;
field 'attr_map';

# XXX: possible future config options:
#           timeout
#           localaddr

# XXX: the 'id' field does NOT need to be exposed to users via any sort of UI;
#      its for internally segregating one LDAP configuration from another,
#      even if the user goes in and changes all of the other information about
#      the connection (hostname, port, descriptive name, etc).

sub new {
    my ($class, %opts) = @_;
    my $self = \%opts;
    bless $self, $class;

    # make sure we've got all required fields and mapped attributes
    foreach my $field (qw( id host attr_map )) {
        unless ($opts{$field}) {
            st_log->warning( "ST::LDAP::Config: LDAP config missing '$field'" );
            return undef;
        }
    }
    foreach my $attr (qw( user_id username email_address first_name last_name )) {
        unless ($opts{attr_map}{$attr}) {
            st_log->warning( "ST::LDAP::Config: LDAP config missing mapped attribute '$attr'" );
            return undef;
        }
    }

    # return newly created object
    return $self;
}

sub config_filename {
    my $yaml_file = File::Spec->catfile(
        Socialtext::AppConfig->config_dir(),
        'ldap.yaml',
        );
    return $yaml_file;
}

sub load {
    my $class = shift;
    my $filename = $class->config_filename();
    return $class->load_from($filename);
}

sub load_from {
    my ($class, $file) = @_;
    my @config = eval { YAML::LoadFile($file) };
    if ($@) {
        st_log->error( "ST::LDAP::Config: error reading LDAP config in '$file'; $@" );
        return;
    }

    my @objects;
    foreach my $cfg (@config) {
        my $obj = $class->new(%{$cfg});
        unless ($obj) {
            st_log->error( "ST::LDAP::Config: error with LDAP config in '$file'" );
            return;
        }
        push @objects, $obj;
    }
    return wantarray ? @objects : $objects[0];
}

sub save {
    my ($class, @objects) = @_;
    my $filename = $class->config_filename();
    return $class->save_to( $filename, @objects );
}

sub save_to {
    my ($class, $file, @objects) = @_;
    # save un-blessed versions of the config objects (without the YAML header
    # that says that they came from ST::LDAP::Config).
    if ($file) {
        local $YAML::UseHeader=0;
        my @unblessed = map { {%{$_}} } @objects;
        return YAML::DumpFile( $file, @unblessed );
    }
    return 0;
}

sub generate_driver_id {
    # NOTE: generated ID only has to be unique for -THIS- system, it doesn't
    # have to be universally unique across every install.

    # NOTE: generated ID should also be ugly enough that users aren't inclined
    # to want to go in and twiddle the value themselves; hex should be
    # sufficient to deter most users.

    my ($sec, $msec) = gettimeofday();
    my $id = sprintf( '%05x%05x', $msec, $$ );
    return $id;
}

1;

=head1 NAME

Socialtext::LDAP::Config - Configuration object for LDAP connections

=head1 SYNOPSIS

  use Socialtext::LDAP::Config;

  # load LDAP config, from default config filename
  @cfg_objects  = Socialtext::LDAP::Config->load();
  $first_config = Socialtext::LDAP::Config->load();

  # load LDAP config from explicit YAML file
  @cfg_objects  = Socialtext::LDAP::Config->load_from($filename);
  $first_config = Socialtext::LDAP::Config->load_from($filename);

  # save LDAP config, to default config filename
  Socialtext::LDAP::Config->save(@cfg_objects);

  # save LDAP config to explicit YAML file
  Socialtext::LDAP::Config->save_to($filename, @cfg_objects);

  # get path to LDAP configuration file
  $filename = Socialtext::LDAP::Config->config_filename();

  # instantiate based on config hash
  $config = Socialtext::LDAP::Config->new(%ldap_configuration);

  # generate a new unique driver ID
  $driver_id = Socialtext::LDAP::Config->generate_driver_id();

=head1 DESCRIPTION

C<Socialtext::LDAP::Config> encapsulates all of the information for LDAP
connections in configuration object.

LDAP configuration objects can either be loaded from YAML files or created from
a hash of configuration values:

=over

=item B<id> (required)

A B<unique identifier> for the LDAP connection.  This identifier will be used
internally to help denote which LDAP configuration users reside in.

B<DO NOT change this value.>  Doing so will cause any existing users to no
longer be associated with this LDAP configuration.

=item B<name>

Specifies the name for the LDAP connection.  This is a I<descriptive name>,
B<not> the I<host name>.

=item B<backend>

Specifies the name of the LDAP back-end plug-in which is responsible for
connections to this LDAP server.

=item B<base>

Specifies the LDAP "Base DN" which is to be used for searches in the LDAP
directory.

=item B<host> (required)

Specifies a host (or list of hosts) that we are supposed to be connecting to.

Can be provided in any of the following formats:

  ip.add.re.ss
  hostname
  ldap://hostname
  ldaps://hostname

Any of the above formats may include a TCP port number (e.g. "127.0.0.1:389").

=item B<port>

Specifies the TCP port number that the connection should be made to.

=item B<bind_user>

Specifies the username that should be used when binding to the LDAP connection.
If not provided, an anonymous bind will be performed.

=item B<bind_password>

Specifies the password that should be used when binding to the LDAP connection.

=item B<filter>

Specifies a LDAP filter (e.g. C<(objectClass=inetOrgPerson)>) that should be
applied and used with B<ALL> queries/searches.

=item B<follow_referrals>

Specifies whether or not LDAP referral responses from this server are followed
or not.  Defaults to "1" (follow referrals).

=item B<attr_map> (required)

Maps Socialtext user attributes to their underlying LDAP representations.

=back

=head1 METHODS

=over

=item B<Socialtext::LDAP::Config-E<gt>new(%config)>

Instantiates a new configuration object based on the provided hash of
configuration options.

=item B<Socialtext::LDAP::Config-E<gt>config_filename()>

Returns the full path to the LDAP configuration file.

=item B<Socialtext::LDAP::Config-E<gt>load()>

Loads LDAP configuration from the default LDAP configuration file.

Contents of the configuration file are returned in an appropriate context.  In
list context you get a list of all of the known LDAP configurations (as
C<Socialtext::LDAP::Config> objects).  In scalar context you get a
C<Socialtext::LDAP::Config> object for the I<first> LDAP configuration defined
in the file.

=item B<Socialtext::LDAP::Config-E<gt>load_from($filename)>

Loads LDAP configuration from the specified configuration file.

Contents returned in an appropriate context, as outlined in L<load()> above.

=item B<Socialtext::LDAP::Config-E<gt>save(@objects)>

Saves the given C<Socialtext::LDAP::Config> objects out to the default LDAP
configuration file.  Any existing configuration present in the file is
over-written.

Returns true if we're able to save the configuration, false otherwise.

=item B<Socialtext::LDAP::Config-E<gt>save_to($filename, @objects)>

Saves the given C<Socialtext::LDAP::Config> objects out to the specified
configuration file.  Any existing configuration present in the file is
over-written.

Returns true if we're able to save the configuration, false otherwise.

=item B<Socialtext::LDAP::Config->generate_driver_id()>

Generates a new unique driver identifier.

=back

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
