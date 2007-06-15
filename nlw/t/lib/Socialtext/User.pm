package Socialtext::User;
# @COPYRIGHT@
use strict;
use warnings;

sub new {
    my ($class, %opts) = @_;
    my $self = \%opts;
    bless $self, $class;
    return $self;
}

sub confirm_email_address {}

sub confirmation_uri { 'blah/nlw/submit/confirm/foo' }

sub FormattedEmail { 'One Loser <one@foo.bar>' }

1;
