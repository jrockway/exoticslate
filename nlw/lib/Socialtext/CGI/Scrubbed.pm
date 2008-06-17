package Socialtext::CGI::Scrubbed;
use strict;
use warnings;
use base 'CGI';
use Class::Field 'field';
use HTML::Scrubber;

field 'scrubber', -init => 'HTML::Scrubber->new(deny => [qw(script)])';

sub param {
    my $self = shift;
    my @result = map { $self->scrubber->scrub($_) }
                 $self->SUPER::param(@_);
    return wantarray ? @result : $result[0];
}

1;
