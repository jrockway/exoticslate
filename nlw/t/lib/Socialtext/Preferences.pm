package Socialtext::Preferences;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::MockBase';

our $AUTOLOAD;
sub AUTOLOAD {
    $AUTOLOAD =~ s/.+:://;
    return Socialtext::MockPreference->new(value => $AUTOLOAD);
}

package Socialtext::MockPreference;
use strict;
use warnings;
use base 'Socialtext::MockBase';

sub value { $_[0]->{value} }

1;
