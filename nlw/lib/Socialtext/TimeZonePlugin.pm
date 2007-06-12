# @COPYRIGHT@
package Socialtext::TimeZonePlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';

use Class::Field qw( const );
use Time::Local ();

sub class_id { 'timezone' }
const class_title => 'Time';
const zones => {'-1200' => '-1200 International Date Line West',
                '-1100' => '-1100 Nome',
                '-1000' => '-1000 Hawaii, Central Alaska',
                '-0900' => '-0900 Yukon',
                '-0800' => '-0800 Pacific',
                '-0700' => '-0700 Mountain',
                '-0600' => '-0600 Central (Americas)',
                '-0500' => '-0500 Eastern (Americas)',
                '-0400' => '-0400 Atlantic',
                '-0330' => '-0330 Newfoundland',
                '-0300' => '-0300 Greenland',
                '-0200' => '-0200 Oscar',
                '-0100' => '-0100 West Africa',
                '+0000' => '+0000 UTC/GMT, Western European',
                '+0100' => '+0100 Central European',
                '+0200' => '+0200 Eastern European',
                '+0300' => '+0300 Baghdad',
                '+0330' => '+0330 Iran',
                '+0400' => '+0400 Delta/USSR Zone 3',
                '+0500' => '+0500 Echo/USSR Zone 4',
                '+0530' => '+0530 Indian',
                '+0600' => '+0600 Foxtrot/USSR Zone 5',
                '+0700' => '+0700 Golf/USSR Zone 6',
                '+0800' => '+0800 Western Australian, China Coast',
                '+0900' => '+0900 Japan, Korean',
                '+0930' => '+0930 Central Australian',
                '+1000' => '+1000 Eastern Australian, Guam',
                '+1100' => '+1100 Lima',
                '+1200id' => '+1200 International Date Line East',
                '+1200nz' => '+1200 New Zealand',
               };

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(preference => $self->timezone);
    $registry->add(preference => $self->dst);
    $registry->add(preference => $self->date_display_format);
    $registry->add(preference => $self->time_display_12_24);
    $registry->add(preference => $self->time_display_seconds);
}

sub timezone {
    my $self = shift;
    my $p = $self->new_preference('timezone');
    $p->query('What time zone should times be displayed in?');
    $p->type('pulldown');
    my $zones = $self->zones;
    my $choices = [map {$_ => $zones->{$_}} sort keys %$zones];
    $p->choices($choices);
    $p->default('-0800');
    return $p;
}

sub dst {
    my $self = shift;
    my $p = $self->new_preference('dst');
    $p->query('How should Daylight Savings/Summer Time be handled?');
    $p->type('pulldown');
    my $choices = [
        'on' => 'currently in DST',
        'off' => 'currently not in DST',
        'auto-us' => 'automatic, United States',
        'never' => 'never in DST',
    ];
    $p->choices($choices);
    $p->default('auto-us');
    return $p;
}

sub date_display_format {
    my $self = shift;
    my $p = $self->new_preference('date_display_format');
    $p->query('How should displayed dates be formatted?');
    $p->type('pulldown');
    my $time = time;
    my $choices = [];
    for ( qw(mmm_d d_mmm mm_dd mmm_d_yyyy d_mmm_yy yyyy_mm_dd) ) {
        push @{$choices}, $_;
        push @{$choices}, $self->get_date($time, $_, 24, 0) =~ /(.+) \d+:/;
    }
    $p->choices($choices);
    $p->default('mmm_d');
    return $p;
}

sub time_display_12_24 {
    my $self = shift;
    my $p = $self->new_preference('time_display_12_24');
    $p->query('Should times be displayed in 12-hour or 24-hour format?');
    $p->type('radio');
    my $choices = [
        12 => '12-hour (am/pm)',
        24 => '24-hour',
    ];
    $p->choices($choices);
    $p->default(12);
    return $p;
}

sub time_display_seconds {
    my $self = shift;
    my $p = $self->new_preference('time_display_seconds');
    $p->query('Should seconds be included on displayed times?');
    $p->type('boolean');
    $p->default(0);
    return $p;
}

sub timezone_seconds {
    my $self = shift;
    my $time = shift || time;
    my $timezone = $self->preferences->timezone->value;

    # XXX This must be checked for passing, before we use $2 or $3
    $timezone =~ /([-+])(\d\d)(\d\d)/;
    my $offset = (($2 * 60) + $3) * 60;
    $offset *= -1 if $1 eq '-';

    my $dst = $self->preferences->dst->value;

    my $isdst = (localtime($time))[8];

    $offset += $dst eq 'on'
               ? 3600
               : ($dst eq 'auto-us' and $isdst)
                 ? 3600
                 : 0;

    return $offset;
}

sub date_local {
    my $self = shift;
    my $date = shift;

    return unless defined $date;

    # We seems to have some bad data in the system, so the best we can
    # do is just return the date as is, since trying to localize it
    # will probably just mangle it even worse-.
    $date =~ /(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/
        or return $date;

    my ($year, $mon, $mday, $hour, $min, $sec) = ($1, $2, $3, $4, $5, $6);

    my $time = Time::Local::timegm($sec, $min, $hour, $mday, $mon - 1, $year);
    return $self->get_date_user($time + $self->timezone_seconds($time));
}

sub get_date_user {
    my $self = shift;
    my $time = shift;
    my $prefs = $self->preferences;
    $self->get_date (
        $time,
        $prefs->date_display_format->value,
        $prefs->time_display_12_24->value,
        $prefs->time_display_seconds->value,
    );
}

my %WithYear = (
    mm_dd => 'yyyy_mm_dd',
    d_mmm => 'd_mmm_yy',
    mmm_d => 'mmm_d_yyyy',
);
sub get_date {
    my $self = shift;
    my $time = shift;
    my $date_display_format = shift;
    my $time_display_12_24 = shift;
    my $time_display_seconds = shift;
    my ($d, $t);
    my @month_string = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

    my ($sec, $min, $hour, $mday, $mon, $year) = gmtime($time);

    if ( $year != (gmtime)[5]
         and $WithYear{$date_display_format}) {
        $date_display_format = $WithYear{$date_display_format};
    }

    $d = sprintf("%02d-%02d", $mon + 1, $mday)
        if $date_display_format eq 'mm_dd';
    $d = sprintf("%d-%s", $mday, $month_string[$mon])
        if $date_display_format eq 'd_mmm';
    $d = sprintf("%s %d", $month_string[$mon], $mday)
        if $date_display_format eq 'mmm_d';

    $d = sprintf("%4d-%02d-%02d", $year + 1900, $mon + 1, $mday)
        if $date_display_format eq 'yyyy_mm_dd';
    $d = sprintf("%d-%s-%02d", $mday, $month_string[$mon], $year - 100)
        if $date_display_format eq 'd_mmm_yy';
    $d = sprintf("%s %d, %4d", $month_string[$mon], $mday, $year + 1900)
        if $date_display_format eq 'mmm_d_yyyy';

    my $ampm = '';
    if ($time_display_12_24 eq 12) {
        $ampm = 'am';
        $ampm = 'pm'  if ($hour > 11);
        $hour -= 12 if ($hour > 12);
        $hour = 12 if ($hour == 0);
        $t = sprintf("%d:%02d", $hour, $min);
    }
    else {
        $t = sprintf("%02d:%02d", $hour, $min);
    }

    $t .= sprintf(":%02d", $sec) if $time_display_seconds;

    return( "$d $t$ampm" );
}

1;
