package Socialtext::NTLM::Config;
# @COPYRIGHT@

use strict;
use warnings;
use Class::Field qw(field);
use File::Spec;
use YAML;
use Socialtext::AppConfig;
use Socialtext::Log qw(st_log);

field 'domain';
field 'primary';
field 'backup';

###############################################################################
# Do we allow for missing fields in the config?  Default is to fail on missing
# fields.  We allow for missing fields in "st-ntlm-config", as we may be
# working with an incomplete NTLM configuration.
our $allow_missing = 0;

###############################################################################
sub new {
    my ($class, %opts) = @_;
    my $self = \%opts;
    bless $self, $class;

    # make sure we've got all required fields
    foreach my $field (qw( domain primary )) {
        unless ($opts{$field}) {
            st_log->warning( "ST::NTLM::Config: NTLM config missing '$field'" );
            return undef;
        }
    }

    # return newly created object
    return $self;
}

sub config_filename {
    my $yaml_file = File::Spec->catfile(
        Socialtext::AppConfig->config_dir(),
        'ntlm.yaml',
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
        st_log->error( "ST::NTLM::Config: error reading NTLM config in '$file'; $@" );
        return;
    }

    my @objects;
    foreach my $cfg (@config) {
        my $obj = $class->new( %{$cfg} );
        unless ($obj) {
            st_log->error( "ST::NTLM::Config: error with NTLM config in '$file'" );
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
    # save un-blessed versions of the config objects (without the YTML header
    # that says that they came from ST::NTLM::Config).
    if ($file) {
        local $YAML::UseHeader = 0;
        my @unblessed = map { {%{$_}} } @objects;
        return YAML::DumpFile( $file, @unblessed );
    }
    return;
}

1;

=head1 NAME

Socialtext::NTLM::Config - Configuration object for NTLM Authentication

=head1 SYNOPSIS

  use Socialtext::NTLM::Config;

  # load NTLM config, from default config filename
  @cfg_objects  = Socialtext::NTLM::Config->load();
  $first_config = Socialtext::NTLM::Config->load();

  # load NTLM config, from explicit YAML file
  @cfg_objects  = Socialtext::NTLM::Config->load_from($filename);
  $first_config = Socialtext::NTLM::Config->load_from($filename);

  # save NTLM config, to default config filename
  Socialtext::NTLM::Config->save(@cfg_objects);

  # save NTLM config to explicit YAML file
  Socialtext::NTLM::Config->save_to($filename, @cfg_objects);

  # get path to NTLM configuration file
  $filename = Socialtext::NTLM::Config->config_filename();

  # instantiate based on config hash
  $config = Socialtext::NTLM::Config->new(%ntlm_configuration);

=head1 DESCRIPTION

C<Socialtext::NTLM::Config> encapsulates all of the information describing the
NTLM Domains and Domain Controllers that can be used for authentication
purposes.

NTLM configuration objects can either be loaded from YAML files or created
from a hash of configuration values:

=over

=item B<domain> (required)

The name of the NT Domain.

=item B<primary> (required)

The name of the Primary Domain Controller for the domain.

=item B<backup>

The name(s) of the Backup Domain Controllers for the domain.

=back

=head1 METHODS

=over

=item B<Socialtext::NTLM::Config-E<gt>new(%config)>

Instantiates a new configuration object base on the provided hash of
configuration options.

=item B<Socialtext::NTLM::Config-E<gt>config_filename()>

Returns the full path to the NTLM configuration file.

=item B<Socialtext::NTLM::Config-E<gt>load()>

Loads NTLM configuration from the default NTLM configuration file.

Contents of the configuration file are returned in an appropriate context.  In
list context you get a list of all of the known NTLM configurations (as
C<Socialtext::NTLM::Config> objects).  In a scalar context you get a
C<Socialtext::NTLM::Config> object for the I<first> configuration defined in
the file.

=item B<Socialtext::NTLM::Config-E<gt>load_from($filename)>

Loads NTLM configuration from the specified configuration file.

Contents returned in an appropriate context, as outlined in L<load()> above.

=item B<Socialtext::NTLM::Config-E<gt>save(@objects)>

Saves the given C<Socialtext::NTLM::Config> objects out to the default NTLM
configuration file.  Any existing configuration present in the file is
over-written.

Returns true if we're able to save the configuration, false otherwise.

=item B<Socialtext::NTLM::Config-E<gt>save_to($filename, @objects)>

Saves the given C<Socialtext::NTLM::Config> objects out to the specified
configuration file.  Any existing configuration present in the file is
over-written.

Returns true if we're able to save the configuration, false otherwise.

=back

=head1 AUTHOR

Socialtext, Inc., C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
