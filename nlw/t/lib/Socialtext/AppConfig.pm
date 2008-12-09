package Socialtext::AppConfig;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::MockBase';

our $DEFAULT_WORKSPACE = 'default';
our $CODE_BASE = '/codebase';
our $SCRIPT_NAME = '/scripts';

sub db_connect_params {+{
    db_name => "NLW_$ENV{USER}_testing",
    user => $ENV{USER},
}}

sub syslog_level { 1 }

sub default_workspace { $DEFAULT_WORKSPACE }

sub code_base { $CODE_BASE }
sub script_name { $SCRIPT_NAME }

sub user_factories { 'Default' }

sub data_root_dir { '/datadir' }

sub stats { 'stats' }
sub config_dir { '/config_dir' }
sub template_compile_dir { 't/tmp' }

sub locale { 'en' }
sub debug { 0 }

sub web_hostname { 'mock_web_hostname' }
sub custom_http_port { 'custom_http_port' }
sub instance { Socialtext::AppConfig->new }

sub _startup_user_is_human_user { 0 }

1;
