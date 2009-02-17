#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use mocked 'Apache::Request', qw( get_log_reasons );
use Socialtext::CredentialsExtractor;
use Socialtext::AppConfig;
use Test::Socialtext tests => 2;

###############################################################################
# Fixtures: base_config
#
# Need to have the config files present/available, but don't need anything
# else.
fixtures(qw( base_config ));

###############################################################################
### TEST DATA
###############################################################################
my $creds_extractors = 'Guest';

###############################################################################
# TEST: Always fails to authenticate
guest_is_always_failure: {
    # create a mocked Apache::Request to extract the credentials from
    my $mock_request = Apache::Request->new();

    # configure the list of Credentials Extractors to run
    Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

    # extract the credentials
    my $username
        = Socialtext::CredentialsExtractor->ExtractCredentials($mock_request);
    is $username, undef, 'Guest credentials are always "undef"';

    # make sure that nothing got logged as a failure
    my @reasons = get_log_reasons();
    ok !@reasons, '... no failures logged';
}
