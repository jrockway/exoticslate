package Socialtext::Rest::AccountUsers;
# @COPYRIGHT@

use strict;
use warnings;
use base 'Socialtext::Rest::Collection';
use Socialtext::Account;
use Socialtext::JSON qw/decode_json/;
use Socialtext::HTTP ':codes';
use Socialtext::String;
use Socialtext::User;

sub allowed_methods { 'POST' }
sub collection_name { 'Account Users' }

sub POST_json {
    my $self = shift;
    my $rest = shift;
    my $data = decode_json( $rest->getContent() );

    unless ( $self->_user_is_business_admin_p ) {
        $rest->header(
            -status => HTTP_401_Unauthorized,
        );
        return '';
    }

    unless ( defined $data->{email_address} ) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
        );
        return '';
    }

    my $account = Socialtext::Account->new( 
        name => Socialtext::String::uri_escape( $self->acct ),
    );

    unless ( defined $account ) {
        $rest->header(
            -status => HTTP_404_Not_Found,
        );
        return '';
    }

    my $user = Socialtext::User->new(
        email_address => $data->{email_address},
    );

    unless ( defined $user ) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
        );
        return '';
    }

    eval{ $user->primary_account($account->account_id); };

    if ( $@ ) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
        );
        return '';
    }

    $rest->header(
        -status => HTTP_200_OK,
    );
    return '';
}

1;
