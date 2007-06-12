package Socialtext::Rest::Comments;
# @COPYRIGHT@

use strict;
use warnings;

use base 'Socialtext::Rest';
use Socialtext::HTTP ':codes';

sub allowed_methods {'POST'}
sub permission      { +{ POST => 'comment' } }

sub POST {
    my ( $self, $rest ) = @_;

    $self->if_authorized(
        POST => sub {
            if ( $self->page->content eq '' ) {
                $rest->header(
                    -status => HTTP_404_Not_Found,
                    -type   => 'text/plain'
                );
                return "There is no page called '" . $self->pname . "'";
            }
            else {
                $self->page->add_comment( $rest->getContent );
                $rest->header( -status => HTTP_204_No_Content );
            }
        }
    );
}

1;
