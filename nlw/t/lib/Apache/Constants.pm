package Apache::Constants;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Exporter';
our @EXPORT_OK = qw(FORBIDDEN REDIRECT);

sub FORBIDDEN { 1 }
sub REDIRECT  { 302 }

1;
