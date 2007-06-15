package Socialtext::HTTPPorts;
# @COPYRIGHT@

use warnings;
use strict;

use base 'Exporter';

our @EXPORT_OK = qw(SSL_PORT_DIFFERENCE);

sub SSL_PORT_DIFFERENCE { 1000 }

=head1 NAME

Socialtext::HTTPPorts - Information about Socialtext HTTP ports

=head1 SYNOPSIS

use Socialtext::HTTP 'SSL_PORT_DIFFERENCE';

=head1 RATIONALE

The SSL_PORT_DIFFERENCE method provides a central place in which
to keep the information used to generation SSL ports in dev-envs
and the apache_perl backend. The numeral 1000 was being copied all
over the place. 

=cut

1;
