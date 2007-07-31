# @COPYRIGHT@
package Socialtext::l10n;
use strict;
use warnings;
use base 'Exporter';

our @EXPORT_OK = qw(best_locale system_locale loc loc_lang valid_code available_locales);
our $CUR_LOCALE = 'en';
our $SYS_LOCALE = 'en';

# XXX: Might want something smarter.  I didn't need this for my purposes.
sub loc {
    my $str = shift;
    for my $n ( 1 .. @_ ) {
        my $value = $_[$n-1];
        $str =~ s/\[_$n\]/$value/g;
    }
    return $str;
}

sub loc_lang {
    $CUR_LOCALE = shift if @_;
    return $CUR_LOCALE;
}

sub valid_code { 1 }

sub best_locale {
    return loc_lang() || system_locale();
}

sub system_locale {
    $SYS_LOCALE = shift if @_;
    return $SYS_LOCALE;
}

sub available_locales { { en => 'English' } }

1;
