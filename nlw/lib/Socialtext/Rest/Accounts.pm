package Socialtext::Rest::Accounts;
# @COPYRIGHT@

use warnings;
use strict;

use Class::Field qw( const field );
use JSON;
use Socialtext::HTTP ':codes';
use Socialtext::Account;
use Socialtext::Exceptions;
use base 'Socialtext::Rest::Collection';

sub allowed_methods {'GET, HEAD, PUT, POST'}

field errors        => [];

# We punt to the permission handling stuff below.
sub permission { +{ GET => undef } }

sub collection_name {
    'Accounts';
}

sub POST {
    my $self = shift;
    my $rest = shift;
    
    my $account_request_hash = jsonToObj( $rest->getContent() );
    my $new_account_name = $account_request_hash->{name};

    unless ($self->_user_is_business_admin_p( ) ) {
        $rest->header(
                      -status => HTTP_401_Unauthorized,
                     );
        return '';
    }

    my $account = $self->_create_account( $new_account_name );
    if( $account ) {
        $rest->header(
                      -status => HTTP_201_Created,
                      -type   => 'application/json',
                      -Location => $self->full_url('/', $account->account_id),
                     );
        my $account_info_hash =
          {
           account_id => $account->account_id,
           name => $account->name,
          };
            
                                 
        return objToJson( $account_info_hash );
    } else {
        # hrmm, what to do here for errors, I'm going with FORBIDDEN for now
        $rest->header(
                      -status => HTTP_403_Forbidden,
                      -type   => 'text/plain',
                     );
        return join( "\n", @{$self->errors} );
    }
}

sub _create_account {
    my $self = shift;
    my $new_account_name = shift;
    my $new_account;

    eval {
        $new_account =
          Socialtext::Account->create(
                                      name => $new_account_name
                                     );
        
    };

    if ( my $e
         = Exception::Class->caught('Socialtext::Exception::DataValidation') )
    {
        $self->add_error($_) for $e->messages;
        return;
    }
    return $new_account;
}

sub add_error {
    my $self = shift;
    my $error_message = shift;
    $error_message =~ s/</&lt;/g;
    push @{ $self->errors }, $error_message;
    return 0;
}

1;
