package Socialtext::l10n;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Exporter';
use Socialtext::AppConfig;
our @EXPORT_OK = qw(loc loc_lang system_locale best_locale);

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

=head1 Localization Files

The .po files are kept in share/l10n.

=cut

my $share_dir = Socialtext::AppConfig->new->code_base();
my $l10n_dir = "$share_dir/l10n";

require Locale::Maketext::Simple;
Locale::Maketext::Simple->import (
    Path => $l10n_dir,
    Decode => 1,
    Export => "_loc",  # We have our own loc()
);

sub loc {
    my $msg = shift;

    # Bracket Notation variables are either _digits or _*.
    my $var_rx = qr/_(?:\d+|\*)/;

    # A whitelist of legal Bracket Notation functions we accept.
    # Locale::Maktext will turn [foo,bar] into $lh->foo("bar"), so technically
    # just about anything is legal.  Rather than try to match all the
    # possibilities we'll just have an opt-in whitelist.  Spaces are not
    # allowed around commas in Bracket Notation.
    my $legal_funcs = "(?:" . join("|", (
        qr/quant,$var_rx,.*?/,
        qr/\*,$var_rx,.*?/,    # alias for quant
        qr/numf,$var_rx/,
        qr/\#,$var_rx/,        # alias for numf
        qr/sprintf,.*?/,
        qr/tense,$var_rx,.*?/,
    )) . ")";

    # A legal bracket, or at least the subset we accept, is either a plain
    # variable or a legal func as defined above.
    my $bracket_rx = qr/~*\[(?:$var_rx|$legal_funcs)\]/;

    # RT 26769: Automagically quote square braces.  We do this by splitting
    # the string on the bracket_rx above, which matches legal loc() variables.
    # The capturing parens in the split include the split-item in the list, so
    # we end up with a list of alternating items like this: non-bracket,
    # bracket, non-bracket, ...  Everything that doesn't match the bracket_rx
    # needs to have its square braces quoted.  Care is taken to not requote
    # already quoted braces.
    my $new_msg = "";
    my @parts = split /($bracket_rx)/, $msg; 
    for my $part (@parts) {
        if ( $part =~ /$bracket_rx/ ) {
            $new_msg .= $part;
        }
        else {
            # Quote square braces, but only if they are already not quoted
            # away.  The complication here w/ the tildes is to make sure we
            # have an odd number of tildes, otherwise we have to add an extra
            # one to ensure we're quoting.
            $part =~ s/(~*)(\[|\])/ 
                my $tildes = $1 || "";
                $tildes .= '~' unless length($tildes) % 2;
                $tildes . $2;
            /xeg;
            $new_msg .= $part;
        }
    }

    my $result = _loc( $new_msg, @_ );
    
    # Un-escape escaped %'s - Locale::Maketext::Simple should be doing this!
    $result =~ s/%%/%/g;
    return $result;
}

# Have to wrap this b/c we renamed the real loc() function to _loc()
sub loc_lang { return _loc_lang(@_) }

sub best_locale {
    my $hub = shift;
    my $loc = eval { no warnings; $hub->preferences_object->locale->value };
    return $loc || system_locale();
}

sub system_locale {
    return Socialtext::AppConfig->instance->locale();
}

# Override AppConfig's loc(), b/c of a module cross-dependency
{
    no warnings 'redefine';
    *Socialtext::AppConfig::loc = \&loc;
}

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Socialtext, Inc., All Rights Reserved.

=cut

1;
