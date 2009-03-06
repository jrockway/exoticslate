package Socialtext::NTLM::Config;
# @COPYRIGHT@

use strict;
use warnings;
use Class::Field qw(field const);
use base qw(Socialtext::Config::Base);

###############################################################################
# Name our configuration file
const 'config_basename' => 'ntlm.yaml';

###############################################################################
# Fields that the config file contains
field 'domain';
field 'primary';
field 'backup' => [];

###############################################################################
# Custom initialization routine
sub init {
    my $self = shift;

    # make sure we've got all of our required fields
    my @required = (qw( domain primary ));
    $self->check_required_fields(@required);

    # "backup" should *always* be treated as a list-ref
    my $backup = $self->backup();
    if ($backup and not ref($backup)) {
        $self->backup( [$backup] );
    }
}

1;

=head1 NAME

Socialtext::NTLM::Config - Configuration object for NTLM Authentication

=head1 SYNOPSIS

  # please refer to Socialtext::Base::Config

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

The following methods are specific to C<Socialtext::NTLM::Config> objects.
For more information on other methods that are available, please refer to
L<Socialtext::Base::Config>.

=over

=item B<$self-E<gt>init()>

Custom initialization routine.  Verifies that the configuration contains all
of the required fields, and ensures that the C<backup> field is always treated
in a list-ref context.

=back

=head1 AUTHOR

Socialtext, Inc., C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc., All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Socialtext::Config::Base>.

=cut
