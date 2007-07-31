# @COPYRIGHT@
package Socialtext::Date::l10n;
use strict;
use warnings;
use utf8;

use DateTime::Format::Strptime;
use DateTime::TimeZone;
use Socialtext::Date::l10n::en;

sub get_formated_date {
    my $self = shift;
    my ( $date, $key, $locale ) = @_;

    my $df;
    my $class = 'Socialtext::Date::l10n::' . $locale;
    eval "use $class";
    if ($@) {
        $df = Socialtext::Date::l10n::en->get_date_format($key);
    }
    else {
        $df = $class->get_date_format($key);
    }
    return $df->format_datetime($date);
}

sub get_date_to_year_key_map {
    my $self = shift;
    my ( $key, $locale ) = @_;

    my $newkey;
    my $class = 'Socialtext::Date::l10n::' . $locale;
    eval "use $class";
    if ($@) {
        $newkey = Socialtext::Date::l10n::en->get_date_to_year_key_map($key);
    }
    else{
        $newkey = $class->get_date_to_year_key_map($key);
    }
    return $newkey;
}

sub get_formated_time {
    my $self = shift;
    my ( $time, $key, $locale ) = @_;

    my $df;
    my $class = 'Socialtext::Date::l10n::' . $locale;
    eval "use $class";
    if ($@) {
        $df = Socialtext::Date::l10n::en->get_time_format($key);
    }
    else {
        $df = $class->get_time_format($key);
    }

    return $df->format_datetime($time);
}

sub get_formated_time_sec {
    my $self = shift;
    my ( $time, $key, $locale ) = @_;

    my $df;
    my $class = 'Socialtext::Date::l10n::' . $locale;
    eval "use $class";
    if ($@) {
        $df = Socialtext::Date::l10n::en->get_time_sec_format($key);
    }
    else {
        $df = $class->get_time_sec_format($key);
    }

    return $df->format_datetime($time);
}

sub get_all_format_date {
    my $self = shift;
    my ($locale) = @_;

    my @formats;

    my $class = 'Socialtext::Date::l10n::' . $locale;
    eval "use $class";
    if ($@) {
        @formats = Socialtext::Date::l10n::en->get_date_format_keys;
    }
    else {
        @formats = $class->get_date_format_keys;
    }
    return @formats;
}

sub get_all_format_time {
    my $self = shift;
    my ($locale) = @_;

    my @formats;
    my $class = 'Socialtext::Date::l10n::' . $locale;
    eval "use $class";
    if ($@) {
        @formats = Socialtext::Date::l10n::en->get_time_format_keys;
    }
    else {
        @formats = $class->get_time_format_keys;
    }
    return @formats;
}

1;

