package Socialtext::Locales;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Exporter';
our @EXPORT_OK = qw(valid_code available_locales);

=head1 NAME

Socialtext::Locales - Information about installed locales

=head1 SYNOPSIS

  use Socialtext::Locales qw(valid_code available_locales);

  die unless valid_code('en');
  my $locales = available_locales();

=head1 Methods

=head2 valid_code( $code )

Returns true if the locale code is supported.

=head2 available_locales 

Returns a hash ref of available locales.  The key to the hash is the 
locale code, the value is the locale name.

=cut

sub valid_code { 
    my $code = shift;
    my $available = available_locales();

    # Add sekret locales
    $available->{zz} = 'Hax0r';
    $available->{zj} = 'Japanese Hax0r';

    return $available->{$code};
}

sub available_locales {
    # hardcoded for now, can be dynamic in the future

    use utf8;
    return {
        'en' => _display_locale(loc('English'), 'English'),
        'ja' => _display_locale(loc('Japanese'), '日本語'),
        'it' => _display_locale(loc('Italian'), 'Italiano'),
    };
}

sub _display_locale {
    my ($localized, $native) = @_;
    if ($localized eq $native) {
        return $localized;
    }
    else {
        return "$localized ($native)";
    }
}

sub loc {
    eval qq(require "Socialtext::l10n");
    if ($@) {
        return shift;
    }
    return Socialtext::l10n::loc(@_);
}

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Socialtext, Inc., All Rights Reserved.

=cut

1;
