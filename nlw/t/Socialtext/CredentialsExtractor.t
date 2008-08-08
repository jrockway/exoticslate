#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Apache::Constants;
use mocked 'Apache::Request', qw/get_log_reasons/;
use mocked 'Apache::Cookie';

use Digest::SHA1;
use MIME::Base64;
use Test::Socialtext;
use Socialtext::AppConfig;
use Socialtext::HTTP::Cookie qw(USER_DATA_COOKIE);

fixtures('admin'); # we need some users

BEGIN {
    plan tests => 8;
    use_ok 'Socialtext::CredentialsExtractor';
}

# create a mock Apache request
#
# Things we'll need:
#   - Apache::Cookie->fetch (for Cookie case)
#   - ->connection->user (for Basic Auth case)
#
# Use the default AppConfig case (BasicAuth:Cookie:Guest) with an
# unauthenticated request -> Guest

UNAUTHENTICATED: {
    my $fake_request = Apache::Request->new;
    my $credentials = Socialtext::CredentialsExtractor->ExtractCredentials(
        $fake_request );
    is( $credentials, undef, "No credentials found, baseline is guest/undef");
}

# Use the default AppConfig case (BasicAuth:Cookie:Guest) with user
# cookie -> some User

COOKIE_AUTHENTICATED: {
    local $Apache::Cookie::DATA = {
        USER_DATA_COOKIE() => Apache::Cookie->new(
            value => {
                user_id => 'devnull1@socialtext.com',
                MAC     => Digest::SHA1::sha1_base64(
                    'devnull1@socialtext.com',
                    Socialtext::AppConfig->MAC_secret
                ),
            }
        ),
    };
    my $fake_request = Apache::Request->new;
    my $credentials = Socialtext::CredentialsExtractor->ExtractCredentials(
        $fake_request );
    is $credentials, 'devnull1@socialtext.com', 'devnull1@socialtext.com user loaded from cookie';
    is scalar(get_log_reasons()), 0, 'no reasons logged';
}

COOKIE_BAD_MAC: {
    local $Apache::Cookie::DATA = {
        USER_DATA_COOKIE() => Apache::Cookie->new(
            value => {
                user_id => 'monkey',
                MAC => 'BAD-MAC',
            }
        ),
    };
    my $fake_request = Apache::Request->new;
    my $credentials = Socialtext::CredentialsExtractor->ExtractCredentials(
        $fake_request );
    is $credentials, undef,
        "monkey user failed to load from cookie, got undef";
    my @reasons = get_log_reasons();
    is scalar(@reasons), 1, 'one reasons logged';
    like $reasons[0], qr/Invalid MAC in cookie presented for monkey/;
}

# Use the default AppConfig case (BasicAuth:Cookie:Guest) with Basic Auth
# headers -> some User

HEADER_AUTHENTICATED: {
    # $fake_request->connection->user
    my $fake_request = Apache::Request->new(
        Authorization => 'Basic ' . MIME::Base64::encode('devnull1@socialtext.com:d3vnu11l'),
    );
    my $credentials = Socialtext::CredentialsExtractor->ExtractCredentials(
        $fake_request );
    is $credentials, 'devnull1@socialtext.com', 'devnull1 user loaded from header';
}
