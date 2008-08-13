#!perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext tests => 4;
fixtures( 'admin' );

my $bogus_email = 'humpty@dance.org';
my $legit_email = 'devnull1@socialtext.com';

# Email addresses of non-users should still format in to _something_.
emails_always_format_even_if_nonuser: {
    formatted_like "{user: $bogus_email}", qr(>\Q$bogus_email\E</a>);
}

# Make sure we get a suitable full name for a normal user, and don't just
# reveal his email address.
real_users_show_full_name: {
    my $first_name = 'Devin';
    my $last_name  = 'Nullington';
    my $user       = Socialtext::User->new( email_address => $legit_email );
    isa_ok $user, 'Socialtext::User';

    $user->update_store( first_name => $first_name, last_name => $last_name );

    formatted_like "{user: $legit_email}", qr(>\Q$first_name $last_name\E</a>);

    TODO: {
        local $TODO = <<'';
We actually _do_ reveal the email address in a source comment, for wikiwyg.

        formatted_unlike "{user: $legit_email}", qr/\Q$legit_email\E/;
    }
}
