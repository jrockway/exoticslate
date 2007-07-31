package Socialtext::l10n;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Exporter';
use Socialtext::AppConfig;
our @EXPORT_OK = qw(loc loc_lang valid_code system_locale best_locale
                    available_locales);

=head1 NAME

Socialtext::l10n - Provides localization functions

=head1 SYNOPSIS

  use Socialtext::l10n qw(loc loc_lang);

  loc_lang('fr');                 # set the locale
  is loc('Welcome'), 'Bienvenue'; # find localized text

=head1 Methods

=head2 loc("string [_1]", $arg)

loc() will lookup the english string to find the localized string.  If
no localized string can be found, the english string will be used.

See Locale::Maketext::Simple for information on string formats.

=cut

=head2 loc_lang

Set the locale.

=head2 best_locale( [$hub] )

This function tries to find the "best" locale in the current context.  If a
hub is passed in then we try to find the current user's locale in the current
workspace.  We can't find that (or a hub isn't passed in) then we instead
return the system locale.

=head2 system_locale( )

Returns the current system wide locale code.

=head2 valid_code( $code )

Returns true if the locale code is supported.

=head2 available_locales 

Returns a hash ref of available locales.  The key to the hash is the 
locale code, the value is the locale name.

=head1 Localization Files

The .po files are kept in share/l10n.

=cut

my $share_dir = Socialtext::AppConfig->new->code_base();
my $l10n_dir = "$share_dir/l10n";

require Locale::Maketext::Simple;
Locale::Maketext::Simple->import (
    # This path allows the unit tests to work, but should be removed
    # once the build system puts .po files into the right spot
    Path => $l10n_dir,
    Decode => 1,
);

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

    return {
        'en' => loc('English'),
        'ja' => loc('Japanese'),
    };
}

sub best_locale {
    my $hub = shift;
    my $loc = eval { no warnings; $hub->preferences_object->locale->value };
    return $loc || system_locale();
}

sub system_locale {
    return Socialtext::AppConfig->new->locale();
}

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Socialtext, Inc., All Rights Reserved.

=cut

1;
