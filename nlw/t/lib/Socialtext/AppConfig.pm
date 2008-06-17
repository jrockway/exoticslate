package Socialtext::AppConfig;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::MockBase';

our $DEFAULT_WORKSPACE = 'default';

sub db_connect_params {}

sub syslog_level { 1 }

sub default_workspace { $DEFAULT_WORKSPACE }

1;
