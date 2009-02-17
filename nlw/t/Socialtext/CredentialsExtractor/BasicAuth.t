#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use mocked 'Apache::Request', qw( get_log_reasons );
use MIME::Base64;
use Socialtext::CredentialsExtractor;
use Socialtext::AppConfig;
use Test::Socialtext tests => 10;

###############################################################################
# Fixtures: admin
#
# Need _some_ workspace created, so that we've got a User to extract
# credentials for.
fixtures('admin');

###############################################################################
### TEST DATA
###############################################################################
my $valid_username = Test::Socialtext::Fixture->test_username();
my $valid_password = Test::Socialtext::Fixture->test_password();

my $bad_username = 'unknown_user@socialtext.com';
my $bad_password = '*bad-password*';

my $creds_extractors = 'BasicAuth:Guest';

###############################################################################
# TEST: Username+password are correct, user can authenticate
correct_username_and_password: {
    # create a mocked Apache::Request to extract the credentials from
    my $mock_request = make_mocked_request($valid_username, $valid_password);

    # configure the list of Credentials Extractors to run
    Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

    # extract the credentials
    my $username
        = Socialtext::CredentialsExtractor->ExtractCredentials($mock_request);
    is $username, $valid_username,
        'extracted credentials when username+password are valid';

    # make sure that nothing got logged as a failure
    my @reasons = get_log_reasons();
    ok !@reasons, '... no failures logged';
}

###############################################################################
# TEST: Incorrect password, user cannot authenticate
incorrect_password: {
    # create a mocked Apache::Request to extract the credentials from
    my $mock_request = make_mocked_request($valid_username, $bad_password);

    # configure the list of Credentials Extractors to run
    Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

    # extract the credentials
    my $username
        = Socialtext::CredentialsExtractor->ExtractCredentials($mock_request);
    is $username, undef,
        'unable to extract credentials when password is incorrect';

    # make sure that an appropriate failure reason was logged
    my @reasons = get_log_reasons();
    is scalar(@reasons), 1, '... one failure logged';
    like $reasons[0], qr/unable to authenticate $valid_username for/,
        '... ... noting failure to authenticate user';
}

###############################################################################
# TEST: Unknown username, user cannot authenticate
unknown_username: {
    # create a mocked Apache::Request to extract the credentials from
    my $mock_request = make_mocked_request($bad_username, $bad_password);

    # configure the list of Credentials Extractors to run
    Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

    # extract the credentials
    my $username
        = Socialtext::CredentialsExtractor->ExtractCredentials($mock_request);
    is $username, undef,
        'unable to extract credentials when username is unknown';

    # make sure that an appropriate failure reason was logged
    my @reasons = get_log_reasons();
    is scalar(@reasons), 1, '... one failure logged';
    like $reasons[0], qr/unable to authenticate $bad_username for/,
        '... ... noting failure to authenticate user';
}

###############################################################################
# TEST: No authentication header set, not authenticated
no_authentication_header_set: {
    # create a mocked Apache::Request to extract the credentials from
    my $mock_request = make_mocked_request();

    # configure the list of Credentials Extractors to run
    Socialtext::AppConfig->set(credentials_extractors => $creds_extractors);

    # extract the credentials
    my $username
        = Socialtext::CredentialsExtractor->ExtractCredentials($mock_request);
    is $username, undef,
        'unable to extract credentials when no Authen info provided';

    # make sure that nothing got logged as a failure; if no Authen info is
    # available the Credentials Extractor should exit early
    my @reasons = get_log_reasons();
    ok !@reasons, '... no failures logged';
}



sub make_mocked_request {
    my ($username, $password) = @_;
    my %args = (
        uri => 'http://localhost/nlw/login.html',
    );

    if ($username && $password) {
        my $encoded = MIME::Base64::encode("$username\:$password");
        $args{'Authorization'} = $encoded;
    }

    return Apache::Request->new(%args);
}
