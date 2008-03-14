package Socialtext::Rest::Users;
# @COPYRIGHT@

use warnings;
use strict;

use Class::Field qw( const field );
use JSON::XS;
use Socialtext::HTTP ':codes';
use Socialtext::User;
use Socialtext::Exceptions;
use base 'Socialtext::Rest::Collection';

sub allowed_methods {'GET, HEAD, PUT, POST'}

field errors        => [];

# We punt to the permission handling stuff below.
sub permission { +{ GET => undef } }

sub POST {
    my $self = shift;
    my $rest = shift;

    unless ($self->_user_is_business_admin_p( ) ) {
        $rest->header(
                      -status => HTTP_401_Unauthorized,
                     );
        return '';
    }
    my $create_request_hash = decode_json( $rest->getContent() );

    unless ( $create_request_hash->{username} and
             $create_request_hash->{email_address} ) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
            -type  => 'text/plain', );
        return "username, email_address required";
    }
    
    my ( $new_user ) = eval {
        $self->_create_user(
                            creator => $self->rest->user(),
                            %{$create_request_hash} );
    };

    if ( my $e = Exception::Class->caught('Socialtext::Exception::DataValidation') ) {
        $rest->header(
                      -status => HTTP_400_Bad_Request,
                      -type   => 'text/plain' );
        return join( "\n", $e->messages );
    } elsif ( $@ ) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
            -type   => 'text/plain' );
        # REVIEW: what kind of system logging should we be doing here?
        return "$@";
    }

    $rest->header(
                  -status => HTTP_201_Created,
                  -type   => 'application/json',
                  -Location => $self->full_url('/', $new_user->username()),
                 );
    return '';
}

sub _create_user {
    my $self = shift;
    my %p    = @_;

    my $new_user = Socialtext::User->create( %p );

    return ($new_user);
}
