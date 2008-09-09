package Socialtext::CGI::Scrubbed;
# @COPYRIGHT@
use strict;
use warnings;
use base 'CGI';
use Class::Field 'field';
use HTML::Scrubber;

field 'scrubber', -init => 'HTML::Scrubber->new';

my %dont_scrub = map { $_ => 1 } qw(page_body content comment users_new_ids POSTDATA tag_name);

sub param {
    my $self = shift;
    if (@_ == 1) {
        my $key = $_[0];
        my @res = map { (ref $_ || $dont_scrub{$key}) ? $_ : $self->scrubber->scrub($_) }
                  $self->SUPER::param($key);
        return wantarray ? @res : $res[0];
    }
    return $self->SUPER::param(@_);
}

1;
