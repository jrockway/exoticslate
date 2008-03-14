package Socialtext::LDAP::Config;
# @COPYRIGHT@

use strict;
use warnings;
use Class::Field qw(field);
use YAML;
use Socialtext::Log qw(st_log);

field 'backend';
field 'base';
field 'host';
field 'port';
field 'bind_user';
field 'bind_password';
field 'filter';
field 'attr_map';

# XXX: possible future config options:
#           timeout
#           localaddr

sub new {
    my ($class, %opts) = @_;
    my $self = \%opts;
    bless $self, $class;

    # make sure we've got all required fields and mapped attributes
    foreach my $field (qw( host attr_map )) {
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

sub load {
    my ($class, $file) = @_;
    my $config = eval { YAML::LoadFile($file) };
    if ($@) {
        st_log->error( "ST::LDAP::Config: error reading LDAP config in '$file'; $@" );
        return;
    }

    my $self = $class->new( %{$config} );
    unless ($self) {
        st_log->error( "ST::LDAP::Config: error with LDAP config in '$file'" );
    }
    return $self;
}

sub save {
    my ($self, $file) = @_;
    # save an un-blessed version of ourselves (without the YAML header that
    # says that it came from an ST::LDAP::Config).
    if ($file) {
        local $YAML::UseHeader=0;
        YAML::DumpFile( $file, { %{$self} } );
    }
}

1;

=head1 NAME

Socialtext::LDAP::Config - Configuration object for LDAP connections

=head1 SYNOPSIS

  use Socialtext::LDAP::Config;

  # load YAML file as LDAP config
  $config = Socialtext::LDAP::Config->load($yaml_file);

  # instantiate based on config hash
  $config = Socialtext::LDAP::Config->new(%ldap_configuration);

  # save config as YAML file
  $config->save( $yaml_file );

=head1 DESCRIPTION

C<Socialtext::LDAP::Config> encapsulates all of the information for LDAP
connections in configuration object.

LDAP configuration objects can either be loaded from YAML files or created from
a hash of configuration values:

=over

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

=item B<attr_map> (required)

Maps Socialtext user attributes to their underlying LDAP representations.

=back

=head1 METHODS

=over

=item B<Socialtext::LDAP::Config-E<gt>new(%config)>

Instantiates a new configuration object based on the provided hash of
configuration options.

=item B<Socialtext::LDAP::Config-E<gt>load($file)>

Loads configuration from the specified YAML file and instantiates a new
configuration object.

=item B<save($file)>

Saves the configuration object out to the given YAML file.

=back

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2008 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
