# @COPYRIGHT@
package Socialtext::TimeZonePlugin;
use strict;
use warnings;
use base 'Socialtext::Plugin';

use Class::Field qw( const );
use Time::Local ();

use DateTime;

use Socialtext::Date;
use Socialtext::Date::l10n;
use Socialtext::l10n qw( loc );

sub class_id {'timezone'}
const class_title => loc('Time');

const zones => {
    '-1200'   => loc('-1200 International Date Line West'),
    '-1100'   => loc('-1100 Nome'),
    '-1000'   => loc('-1000 Hawaii, Central Alaska'),
    '-0900'   => loc('-0900 Yukon'),
    '-0800'   => loc('-0800 Pacific'),
    '-0700'   => loc('-0700 Mountain'),
    '-0600'   => loc('-0600 Central (Americas)'),
    '-0500'   => loc('-0500 Eastern (Americas)'),
    '-0400'   => loc('-0400 Atlantic'),
    '-0330'   => loc('-0330 Newfoundland'),
    '-0300'   => loc('-0300 Greenland'),
    '-0200'   => loc('-0200 Oscar'),
    '-0100'   => loc('-0100 West Africa'),
    '+0000'   => loc('+0000 UTC/GMT, Western European'),
    '+0100'   => loc('+0100 Central European'),
    '+0200'   => loc('+0200 Eastern European'),
    '+0300'   => loc('+0300 Baghdad'),
    '+0330'   => loc('+0330 Iran'),
    '+0400'   => loc('+0400 Delta/USSR Zone 3'),
    '+0500'   => loc('+0500 Echo/USSR Zone 4'),
    '+0530'   => loc('+0530 Indian'),
    '+0600'   => loc('+0600 Foxtrot/USSR Zone 5'),
    '+0700'   => loc('+0700 Golf/USSR Zone 6'),
    '+0800'   => loc('+0800 Western Australian, China Coast'),
    '+0900'   => loc('+0900 Japan, Korean'),
    '+0930'   => loc('+0930 Central Australian'),
    '+1000'   => loc('+1000 Eastern Australian, Guam'),
    '+1100'   => loc('+1100 Lima'),
    '+1200id' => loc('+1200 International Date Line East'),
    '+1200nz' => loc('+1200 New Zealand'),
};

sub register {
    my $self     = shift;
    my $registry = shift;
    $registry->add( preference => $self->timezone );
    $registry->add( preference => $self->dst );
    $registry->add( preference => $self->date_display_format );
    $registry->add( preference => $self->time_display_12_24 );
    $registry->add( preference => $self->time_display_seconds );
}

sub timezone {
    my $self   = shift;
    my $locale = $self->hub->best_locale;
    my $p      = $self->new_preference('timezone');
    $p->query( loc('What time zone should times be displayed in?') );
    $p->type('pulldown');
    my $zones = $self->zones;
    my $choices = [ map { $_ => $zones->{$_} } sort keys %$zones ];
    $p->choices($choices);
    $p->default( $self->_default_timezone($locale) );
    return $p;
}

sub _default_timezone {
    my $self;
    my $locale = shift;
    if ( $locale eq 'ja' ) {
        return '+0900';
    }
    else {
        return '-0800';
    }
}

sub dst {
    my $self = shift;
    my $p    = $self->new_preference('dst');

    $p->query( loc('How should Daylight Savings/Summer Time be handled?') );
    $p->type('pulldown');
    my $choices = [
        'on'      => loc('currently in DST'),
        'off'     => loc('currently not in DST'),
        'auto-us' => loc('automatic, United States'),
        'never'   => loc('never in DST'),
    ];
    $p->choices($choices);


    my $locale = $self->hub->best_locale;
    $p->default( $self->_default_dst($locale) );

    return $p;
}

sub _default_dst {
    my $self   = shift;
    my $locale = shift;

    # Only assume DST is "automatic" if the locale is English.
    if ( $locale and $locale eq 'en' ) {
        return 'auto-us';
    }
    else {
        return 'never';
    }
}

sub date_display_format {
    my $self   = shift;
    my $locale = $self->hub->best_locale;

    my $p = $self->new_preference('date_display_format');
    $p->query( loc('How should displayed dates be formatted?') );
    $p->type('pulldown');

    my $time = Socialtext::Date->now( timezone => 'UTC' );

    my $choices = [];

    my @formats = Socialtext::Date::l10n->get_all_format_date($locale);
    for (@formats) {
        if ( $_ eq 'default' ) {
            next;
        }
        push @{$choices}, $_;
        push @{$choices},
        $self->_get_date( $time, $_, $locale );
    }
    $p->choices($choices);
    $p->default('default');

    return $p;
}

sub time_display_12_24 {
    my $self   = shift;
    my $locale = $self->hub->best_locale;
    my $p      = $self->new_preference('time_display_12_24');
    $p->query(
        loc('Should times be displayed in 12-hour or 24-hour format?') );

    my $time;
    my $choices = [];

    $time = Socialtext::Date->now( timezone => 'UTC' );
    $p->type('pulldown');
    my @formats = Socialtext::Date::l10n->get_all_format_time($locale);
    for (@formats) {
        if ( $_ eq 'default' ) {
            next;
        }
        push @{$choices}, $_;
        push @{$choices},
        $self->_get_time( $time, $_, $locale);
    }
    $p->choices($choices);
    $p->default('default');

    return $p;
}

sub time_display_seconds {
    my $self = shift;
    my $p    = $self->new_preference('time_display_seconds');
    $p->query( loc('Should seconds be included on displayed times?') );
    $p->type('boolean');
    $p->default(0);
    return $p;
}

sub adjust_timezone {
    my $self     = shift;
    my $datetime     = shift;
    my $timezone = $self->preferences->timezone->value;

    # XXX This must be checked for passing, before we use $2 or $3
    $timezone =~ /([-+])(\d\d)(\d\d)/;
    my $offset = ( ( $2 * 60 ) + $3 ) * 60;
    $offset *= -1 if $1 eq '-';

    $datetime->add( seconds => $offset );

    return $datetime;
}

sub adjust_dst {
    my $self = shift;
    my $datetime     = shift;
    my $dst = $self->preferences->dst->value;

    my $time = $datetime->epoch;
    my $isdst = ( localtime($time) )[8];

    my $offset =
          $dst eq 'on' ? 3600
        : ( $dst eq 'auto-us' and $isdst ) ? 3600
        : 0;

    $datetime->add( seconds => $offset );

    return $datetime;
}

sub date_local_epoch {
    my $self = shift;
    my $epoch = shift;

    my $locale = $self->hub->best_locale;

    return unless defined $epoch;

    # Make sure we have a valid time.
    $epoch =~ /^\d+$/
        or return $epoch;

    my ( $sec, $min, $hour, $mday, $month, $year, $wday, $yday, $isdst) = gmtime($epoch);

    # XXX to be fixed. in timezone_seconds, adjust time for dst.
    # Now, the routine is deleted, so must adjust in this.
    my $datetime = DateTime->new(
        year      => $year+1900,
        month     => $month+1,
        day       => $mday,
        hour      => $hour,
        minute    => $min,
        second    => $sec,
        time_zone => 'UTC'
    );
    return $self->get_date_user($datetime);
}

sub date_local {
    my $self = shift;
    my $date = shift;

    my $locale = $self->hub->best_locale;

    return unless defined $date;

    # We seems to have some bad data in the system, so the best we can
    # do is just return the date as is, since trying to localize it
    # will probably just mangle it even worse-.
    $date =~ /(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/
        or return $date;

    my ( $year, $mon, $mday, $hour, $min, $sec ) = ( $1, $2, $3, $4, $5, $6 );

    # XXX to be fixed. in timezone_seconds, adjust time for dst.
    # Now, the routine is deleted, so must adjust in this.
    my $datetime = DateTime->new(
        year      => $year,
        month     => $mon,
        day       => $mday,
        hour      => $hour,
        minute    => $min,
        second    => $sec,
        time_zone => 'UTC'
    );
    return $self->get_date_user($datetime);
}

sub get_date_user {
    my $self  = shift;
    my $time  = shift;
    my $prefs = $self->preferences;

    my $locale = $self->hub->best_locale;

    $self->get_date(
        $time,
        $prefs->date_display_format->value,
        $prefs->time_display_12_24->value,
        $prefs->time_display_seconds->value,
        $prefs->timezone->value,
    );
}

sub _get_date {
    my $self = shift;
    my ($time, $date_display_format, $locale) = @_;

    # DateTime parameter '%e' replace leading 0 to space. (when the value is single number)
    # Cut the space.
    my $date_str = Socialtext::Date::l10n->get_formated_date( $time,
            $date_display_format, $locale );
    $date_str =~ s/\s(\d[^\d]+)/$1/g;
    $date_str =~ s/\s(\s)/$1/g;

    return $date_str;
}

sub _get_time {
    my $self = shift;
    my ($time, $time_display_format, $locale) = @_;

    my $time_str = Socialtext::Date::l10n->get_formated_time( $time,
            $time_display_format, $locale );

    # DateTime parameter '%e' replace leading 0 to space. (when the value is single number)
    # Cut the space.
    $time_str =~ s/\s(\d[^\d])/$1/g;
    $time_str =~ s/\s(\s)/$1/g;

    return $time_str;
}

sub _get_time_sec {
    my $self = shift;
    my ($time, $time_display_format, $locale) = @_;

    my $time_str = Socialtext::Date::l10n->get_formated_time_sec( $time,
            $time_display_format, $locale );

    # DateTime parameter '%e' replace leading 0 to space. (when the value is single number)
    # Cut the space.
    $time_str =~ s/\s(\d[^\d])/$1/g;
    $time_str =~ s/\s(\s)/$1/g;

    return $time_str;
}

sub get_date {
    my $self                 = shift;
    my $time                 = shift;
    my $date_display_format  = shift;
    my $time_display_12_24   = shift;
    my $time_display_seconds = shift;
    my $timezone = shift;
    my ( $d, $t );

    my $locale = $self->hub->best_locale;

    my $time_display_format = $time_display_12_24;
    $time = $self->adjust_timezone($time);
    $time = $self->adjust_dst($time);

    # When display year is not equal this year,
    # the formats skipped year must be added year (ref. %WithYear).
    my $now = Socialtext::Date->now( timezone => 'UTC');
    if ($time->year != $now->year){
        $date_display_format = Socialtext::Date::l10n->get_date_to_year_key_map( $date_display_format, $locale );
    }

    $d = $self->_get_date( $time, $date_display_format, $locale );

    if ($time_display_seconds) {
        $t = $self->_get_time_sec( $time, $time_display_format, $locale );
    }else {
        $t = $self->_get_time( $time, $time_display_format, $locale );
    }

    return ("$d $t");
}


sub timezone_seconds {
    my $self     = shift;
    my $time     = shift || time;
    my $timezone = $self->preferences->timezone->value;

    # XXX This must be checked for passing, before we use $2 or $3
    $timezone =~ /([-+])(\d\d)(\d\d)/;
    my $offset = ( ( $2 * 60 ) + $3 ) * 60;
    $offset *= -1 if $1 eq '-';

    my $dst = $self->preferences->dst->value;

    my $isdst = ( localtime($time) )[8];

    $offset +=
          $dst eq 'on' ? 3600
        : ( $dst eq 'auto-us' and $isdst ) ? 3600
        : 0;

    return $offset;
}

1;
