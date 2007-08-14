package Socialtext::User;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::MockBase';

sub confirm_email_address {}

sub confirmation_uri { 'blah/nlw/submit/confirm/foo' }

sub FormattedEmail { 'One Loser <one@foo.bar>' }

sub guess_real_name { 'One Loser' }

sub is_guest { $_[0]->{is_guest} }

sub user_id { 1 }

1;
