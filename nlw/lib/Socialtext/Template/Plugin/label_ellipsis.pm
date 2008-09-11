package Socialtext::Template::Plugin::label_ellipsis;
# @COPYRIGHT@

use strict;
use warnings;

use Template::Plugin::Filter;
use base qw( Template::Plugin::Filter );

my $ellipsis = '...';

sub init {
    my $self = shift;

    $self->{ _DYNAMIC } = 1;

    # first arg can specify filter name
    $self->install_filter($self->{ _ARGS }->[0] || 'label_ellipsis');

    return $self;
}

sub _label_ellipsis {
    my ($string, $length) = @_;
    $length = 32 unless (defined $length);
    
    my $new_string = '';

    return $string if (length($string) <= $length);
    return $ellipsis if (0 == $length);

    my @parts = split / /, $string;

    if (scalar(@parts) == 1) {
        $new_string = substr $string, 0, $length;
    }
    else {
        foreach my $part (@parts) {
            last if ((length($new_string) + length($part)) > $length);
            $new_string .= $part . ' ';
        }
        $new_string = substr($parts[0], 0, $length) if (length($new_string) == 0);

    }

    $new_string =~ s/\s+$//;
    $new_string .= $ellipsis;
    return $new_string;
}

sub filter {
    my ($self, $text, $args, $config) = @_;
    return _label_ellipsis( $text, $args->[0] );
}

1;

=head1 NAME

Socialtext::Template::Plugin::label_ellipsis - TT filter to truncate and add ellipsis to text/labels

=head1 SYNOPSIS

  [% USE label_ellipsis %]
  [% 'some really long string' | label_ellipsis(10) %]

=head1 DESCRIPTION

C<Socialtext::Template::Plugin::label_ellipsis> is a filter plugin for TT,
which truncates the text block to the length specified, or a default length of
32.  Truncated text will be appended with '...' (which does B<not> count
towards the maximum length for truncation).

This filter is similar to the built-in C<truncate> filter provided by TT, with
the notable exceptions:

=over

=item *

C<label_ellipsis> appends the ellipsis to the text I<after> it has been
truncated to the given length, while C<truncate> includes it in the maximum
truncation length.  When using C<label_ellipsis>, expect that the resulting
text could be three characters (the length of the ellipsis) longer than what
you've asked it to truncate at).

E.g.

    [% 'long thing' | label_ellipsis(4) %]
  becomes
    long...

    [% 'long thing' | truncate(4) %]
  becomes
    l...

=item *

C<label_ellipsis> breaks on whitespace, so that we don't chop any words in
half.  C<truncate>, however, truncates immediately at maximum length.

E.g.

    [% 'long thing' | label_ellipsis(6) %]
  becomes
    long...

    [% 'long thing' | truncate(6) %]
  becomes
    lon...

=item *

C<truncate> allows for a different ellipsis to be passed through as a
secondary argument; C<label_ellipsis> does not support such a parameter.

=back

=head1 SEE ALSO

L<Template::Plugin::Filter>,
L<Template::Manual::Filters>.

=cut
