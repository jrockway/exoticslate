#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use mocked 'Apache::Request';
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
my $valid_username = Test::Socialtext::Fixture->test_username();

my $creds_extractors = 'Apache:Guest';

###############################################################################
# TEST: Apache has authenticated User
apache_has_authenticated: {
    # create a mocked Apache::Request to extract the credentials from
    my $mock_request = Apache::Request->new(
        connection_user => $valid_username,
    );

    # configure the list of Credentials Extractors to run
    Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

    # extract the credentials
    my $username
        = Socialtext::CredentialsExtractor->ExtractCredentials($mock_request);
    is $username, $valid_username, 'extracted credentials from Apache';
}

###############################################################################
# TEST: Apache has not authenticated User
apache_has_not_authenticated: {
    # create a mocked Apache::Request to extract the credentials from
    my $mock_request = Apache::Request->new();

    # configure the list of Credentials Extractors to run
    Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

    # extract the credentials
    my $username
        = Socialtext::CredentialsExtractor->ExtractCredentials($mock_request);
    is $username, undef, 'unable to extract credentials; Apache did not authentticate';
}
