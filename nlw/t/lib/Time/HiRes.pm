package Time::HiRes;
use strict;
use warnings;
use base 'Exporter';
our @EXPORT_OK = qw/time/;

our $TIME = 1;

sub time { return $TIME++ }

1;
