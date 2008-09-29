package Socialtext::BrowserDetect;

# @COPYRIGHT@

use strict;
use warnings;

=head1 NAME

Socialtext::BrowserDetect - Determine the Web browser from an HTTP user agent string

=head1 FUNCTIONS

=head2 ie()

Tell if the user agent is MSIE of some kind or another.

=cut

sub ie {
    my $ua = lc $ENV{HTTP_USER_AGENT};

    return (index($ua,'msie') != -1) || (index($ua,'microsoft internet explorer') != -1);
}

=head2 safari()

Tell if the user agent is Safari.

=cut

sub safari {
    my $ua = lc $ENV{HTTP_USER_AGENT};

    return (index($ua,'safari') != -1) || (index($ua,'applewebkit') != -1);
}

=head2 is_mobile()

Tell if the user agent is some sort of mobile browser.

=cut

sub is_mobile {
    # this ENV var should be set by Apache, if it detects a mobile browser
    return $ENV{NLW_MOBILE_BROWSER};
}

# Strings taken from HTTP::BrowserDetect, but boy it's a lot smaller now.

1;
