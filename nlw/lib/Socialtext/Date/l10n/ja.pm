# @COPYRIGHT@
package Socialtext::Date::l10n::ja;
use strict;
use warnings;
use utf8;

my $date_format = {
    'default' => DateTime::Format::Strptime->new(
        pattern   => '%Y-%m-%d',
        locale    => 'ja',
    ),

    'yyyy_mm_dd' => DateTime::Format::Strptime->new(
        pattern   => '%Y-%m-%d',
        locale    => 'ja',
    ),

    'yyyy_mm_dd_sl' => DateTime::Format::Strptime->new(
        pattern   => '%Y/%m/%d',
        locale    => 'ja',
    ),

    'mm_dd_sl' => DateTime::Format::Strptime->new(
        pattern   => '%m/%d',
        locale    => 'ja',
    ),

    'yyyy_mm_dd_jp' => DateTime::Format::Strptime->new(
        pattern   => '%Y年%m月%d日',
        locale    => 'ja',
    ),

    'mm_dd_jp' => DateTime::Format::Strptime->new(
        pattern   => '%m月%d日',
        locale    => 'ja',
    ),
};

my $date_to_year_key_map = {
    'mm_dd_sl' => 'yyyy_mm_dd_sl',
    'mm_dd_jp' => 'yyyy_mm_dd_jp',
};

my $time_format = {
    'default' => DateTime::Format::Strptime->new(
        pattern   => '%H:%M',
        locale    => 'ja',
    ),

    '24' => DateTime::Format::Strptime->new(
        pattern   => '%H:%M',
        locale    => 'ja',
    ),

   '12ampm' => DateTime::Format::Strptime->new(
        pattern   => '%p %I:%M',
        locale    => 'ja',
    ),

   '24_ja' => DateTime::Format::Strptime->new(
        pattern   => '%H時%M分',
        locale    => 'ja',
    ),
};

my $time_sec_format = {
    'default' => DateTime::Format::Strptime->new(
        pattern   => '%H:%M:%S',
        locale    => 'ja',
    ),

    '24' => DateTime::Format::Strptime->new(
        pattern   => '%H:%M:%S',
        locale    => 'ja',
    ),

    '12ampm' => DateTime::Format::Strptime->new(
        pattern   => '%p %I:%M:%S',
        locale    => 'ja',
    ),

   '24_ja' => DateTime::Format::Strptime->new(
        pattern   => '%H時%M分%S秒',
        locale    => 'ja',
    ),
};

sub get_date_format_keys {
    my $self = shift;

    return keys %$date_format;
}

sub get_time_format_keys {
    my $self = shift;

    return keys %$time_format;
}

sub get_date_format {
    my $self = shift;
    my $key  = shift;

    my $df = $date_format->{$key};
    if (! defined $df){
       return $date_format->{'default'};
    }
    return $df;
}

sub get_date_to_year_key_map {
    my $self = shift;
    my $key  = shift;

    my $newkey = $date_to_year_key_map->{$key};
    if (! defined $newkey){
        return $key;
    }
    return $newkey;
}

sub get_time_format {
    my $self = shift;
    my $key  = shift;

    my $df = $time_format->{$key};
    if (! defined $df){
       return $time_format->{'default'};
    }
    return $df;
}

sub get_time_sec_format {
    my $self = shift;
    my $key  = shift;

    my $df = $time_sec_format->{$key};
    if (! defined $df){
       return $time_sec_format->{'default'};
    }
    return $df;
}

1;
