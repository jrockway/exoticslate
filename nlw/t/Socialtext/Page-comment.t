#!perl
# @COPYRIGHT@

use strict;
use warnings;

use Test::Socialtext tests => 1;
fixtures( 'admin' );

use Readonly;

Readonly my $COMMENT => 'You call that a blog post?!';

my $page = new_hub('admin')->pages->new_from_name("Admin wiki");
my $original_body = $page->content;

$page->add_comment( $COMMENT );

like(
    $page->content,
    qr/ \A \Q$original_body\E \s* \n
        --+ \s* \n
        \Q$COMMENT\E \s* \n
        _contributed \s+ by \s+ \{user:\s*devnull1\@socialtext\.com\} \s+
        on \s+ \{date:[^}]+\}_
        \s* \z
    /xsm,
    'Commented page looks correct.'
);
