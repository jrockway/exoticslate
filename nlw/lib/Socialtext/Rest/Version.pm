# @COPYRIGHT@
package Socialtext::Rest::Version;
use warnings;
use strict;

use base 'Socialtext::Rest';
use Socialtext::JSON;
use Readonly;

# Starting from 1 onward, $API_VERSION should be a simple incrementing integer:
# 1: iteration-2008-06-27
# 2: iteration-2009-02-13 (release-3.4)
# 3: iteration-2009-02-27 (release-3.5)
Readonly our $API_VERSION => 3;
Readonly our $MTIME       => ( stat(__FILE__) )[9];

sub allowed_methods {'GET, HEAD'}

sub make_getter {
    my ( $type, $representation ) = @_;
    my @headers = (
        type           => "$type; charset=UTF-8",
        -Last_Modified => __PACKAGE__->make_http_date($MTIME),
    );
    return sub {
        my ( $self, $rest ) = @_;
        $rest->header(@headers);
        return $representation;
    };
}

{
    no warnings 'once';

    *GET_text = make_getter( 'text/plain', $API_VERSION );
    *GET_json
        = make_getter( 'application/json', encode_json( [$API_VERSION] ) );
}

1;
