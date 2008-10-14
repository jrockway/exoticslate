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

sub allowed_methods { 'POST', 'GET' }
sub collection_name { 
    my $acct =  ( $_[0]->acct =~ /^\d+$/ ) 
            ? 'with ID ' . $_[0]->acct
            : $_[0]->acct; 
    return 'Users in Account ' . $acct;
}

sub workspace { return Socialtext::NoWorkspace->new() }
sub ws { '' }

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
        name => Socialtext::String::uri_unescape( $self->acct ),
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

sub permission {
    +{ GET => 'is_business_admin' };
}

sub element_list_item {
   return "<li><a href=\"$_[1]->{uri}\">$_[1]->{name}<a/></li>\n";
}

sub get_resource {
    my $self = shift;
    my $rest = shift;

    my $account = Socialtext::Account->Resolve( $self->acct );
    
    unless ( defined $account ) {
       $rest->header(
           -status => HTTP_404_Not_Found,
        );
        return [];
    };

    return [
        map { $self->_user_representation( $_ ) }
            @{ $account->users_as_hash }
    ];
}

sub _user_representation {
    my $self      = shift;
    my $user_info = shift;

    return +{
        name => $user_info->{email_address},
        uri  => "/data/users/" . $user_info->{email_address},
    }
}

1;
