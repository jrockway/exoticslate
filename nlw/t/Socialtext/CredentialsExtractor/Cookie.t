#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use mocked 'Apache::Request', qw( get_log_reasons );
use mocked 'Apache::Cookie';
use Digest::SHA;
use Socialtext::HTTP::Cookie qw(USER_DATA_COOKIE);
use Socialtext::AppConfig;
use Socialtext::CredentialsExtractor;
use Test::Socialtext tests => 7;
use Test::Socialtext::User;

###############################################################################
# Fixtures: base_config
#
# Need to have the config files present/available, but don't need anything
# else.
fixtures(qw( base_config ));

###############################################################################
### TEST DATA
###############################################################################
my $valid_username = Test::Socialtext::User->test_username();
my $cookie_name    = USER_DATA_COOKIE();

my $creds_extractors = 'Cookie:Guest';

###############################################################################
# TEST: Cookie present, user can authenticate
cookie_ok: {
    # create a mocked Apache::Request to extract the credentials from
    my $mock_request = Apache::Request->new();

    # create the cookie data
    local $Apache::Cookie::DATA = {
        $cookie_name => Apache::Cookie->new(
            value => {
                user_id => $valid_username,
                MAC     => Digest::SHA::sha1_base64(
                    $valid_username,
                    Socialtext::AppConfig->MAC_secret()
                ),
            },
        ),
    };

    # configure the list of Credentials Extractors to run
    Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

    # extract the credentials
    my $username
        = Socialtext::CredentialsExtractor->ExtractCredentials($mock_request);
    is $username, $valid_username, 'extracted credentials from HTTP cookie';

    # make sure that nothing got logged as a failure
    my @reasons = get_log_reasons();
    ok !@reasons, '... no failures logged';
}

###############################################################################
# TEST: Cookie present, but contains bad MAC, not authenticated
cookie_has_bad_mac: {
    # create a mocked Apache::Request to extract the credentials from
    my $mock_request = Apache::Request->new();

    # create the cookie data
    local $Apache::Cookie::DATA = {
        $cookie_name => Apache::Cookie->new(
            value => {
                user_id => $valid_username,
                MAC     => 'THIS-IS-A-BAD-MAC',
            },
        ),
    };

    # configure the list of Credentials Extractors to run
    Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

    # extract the credentials
    my $username
        = Socialtext::CredentialsExtractor->ExtractCredentials($mock_request);
    is $username, undef, 'unable to extract credentials when MAC is bad';

    # make sure that nothing got logged as a failure
    my @reasons = get_log_reasons();
    is scalar(@reasons), 1, '... one failure logged';
    like $reasons[0], qr/Invalid MAC in cookie/, '... ... noting the invalid MAC';
}

###############################################################################
# TEST: Cookie missing, not authenticated
cookie_missing: {
    # create a mocked Apache::Request to extract the credentials from
    my $mock_request = Apache::Request->new();

    # configure the list of Credentials Extractors to run
    Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

    # extract the credentials
    my $username
        = Socialtext::CredentialsExtractor->ExtractCredentials($mock_request);
    is $username, undef,
        'unable to extract credentials when cookie is missing';

    # make sure that nothing got logged as a failure
    my @reasons = get_log_reasons();
    ok !@reasons, '... no failures logged';
}
