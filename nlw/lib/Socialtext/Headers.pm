# @COPYRIGHT@
package Socialtext::Headers;
use strict;
use warnings;

use base 'Socialtext::Base';

use Socialtext::WebHelpers ':headers';

use Class::Field qw( field );


sub class_id { 'headers' }

field content_type => 'text/html';
field content_disposition => undef;
field content_length => undef;
field charset => 'UTF-8';
field expires => 'now';
field pragma => 'no-cache';
field cache_control => 'no-store, no-cache, must-revalidate, post-check=0, pre-check=0';
field last_modified => -init => 'scalar gmtime';

# Erase certain cache headers which will prevent IE 6/7 from downloading
# attachments under SSL.
# 
# See: http://support.microsoft.com/default.aspx?scid=kb;en-us;812935
sub erase_cache_headers {
    my $self = shift;
    $self->cache_control(undef);
    $self->pragma(undef);
}

sub add_attachment {
    my ( $self, %args ) = @_;
    $self->content_disposition("attachment; filename=\"$args{filename}\"");
    $self->content_type( $args{type} || 'text/html' );
    $self->content_length( $args{len} );
    $self->erase_cache_headers();
}

1;
