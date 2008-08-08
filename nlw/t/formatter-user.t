#!perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext tests => 10;
fixtures( 'admin' );

my $hub = new_hub('admin');
my $bogus_email = 'humpty@dance.org';
my $legit_email = 'devnull1@socialtext.com';

# Email addresses of non-users should still format in to _something_.
{
    formatted_like( "{user: $bogus_email}", qr(>\Q$bogus_email\E</a>) );
}

# Make sure we get a suitable full name for a normal user, and don't just
# reveal his email address.
{
    my $first_name = 'Devin';
    my $last_name  = 'Nullington';
    my $user       = Socialtext::User->new( email_address => $legit_email );
    isa_ok( $user, 'Socialtext::User' );

    $user->update_store( first_name => $first_name, last_name => $last_name );

    formatted_like(
        "{user: $legit_email}",
        qr(>\Q$first_name $last_name\E</a>)
    );

    TODO: {
        local $TODO = <<'';
We actually _do_ reveal the email address in a source comment, for wikiwyg.

        formatted_unlike( "{user: $legit_email}", qr/\Q$legit_email\E/ );
    }
}

# EXTRACT: The next four belong in some Socialtext testing package,
# please? -mml

sub formatted_like {
    unshift @_, 1;
    goto &_formatted_pattern;
}

sub formatted_unlike {
    unshift @_, 0;
    goto &_formatted_pattern;
}

sub _formatted_pattern {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my ( $similar_p, $wikitext, $pattern, $message ) = @_;

    $message ||= $wikitext;

    my $page = make_page("Page to test $message", $wikitext);
    isa_ok( $page, 'Socialtext::Page' );
    if ($similar_p) {
        like $page->to_html, $pattern, $message;
    } else {
        unlike $page->to_html, $pattern, $message;
    }
}

sub make_page {
    my ( $name, $content ) = @_;

    my $page = $hub->pages->new_from_name($name);
    isa_ok( $page, 'Socialtext::Page' );

    $page->metadata->Subject($name);
    $page->metadata->update( user => $hub->current_user );
    $page->content($content);
    $page->store( user => $hub->current_user );

    return $page;
}

