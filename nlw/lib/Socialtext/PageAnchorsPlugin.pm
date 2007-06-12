# @COPYRIGHT@
package Socialtext::PageAnchorsPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

sub class_id { 'page_anchors' }

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(wafl => section => 'Socialtext::PageAnchorsWafl');
}

package Socialtext::PageAnchorsWafl;

use base 'Socialtext::Formatter::WaflPhrase';

sub html {
    my $self = shift;
    my $anchor = Socialtext::Page->name_to_id($self->arguments);
    return qq{<a name="$anchor"><span class="ugly-ie-css-hack" style="display:none;">&nbsp;</span></a>};
}

1;

