#!perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Live fixtures => ['admin'];
# Importing Test::Socialtext will cause it to create fixtures now, which we
# want to happen want to happen _after_ Test::Live stops any running
# Apache instances, and all we really need here is Test::More.
use Test::More;
use Socialtext::Workspace;

plan tests => 9;

my $live = Test::Live->new();
my $base_uri = $live->base_url;
$live->log_in();

{
    $live->mech()->post(
        "$base_uri/admin/index.cgi", {
            action        => 'users_invite',
            Button        => 'Invite',
            users_new_ids => <<'EOF',
devnull3@socialtext.com
devnull4@socialtext.com
EOF
        },
    );
    my $content = $live->mech()->content();
    like( $content, qr/following users/,
          'check server response for success message' );
    like( $content, qr/devnull3\@socialtext\.com/,
          'response says devnull3 was invited' );
    like( $content, qr/devnull4\@socialtext\.com/,
          'response says devnull4 was invited' );

    my $ws = Socialtext::Workspace->new( name => 'admin' );
    for my $username ( qw( devnull3@socialtext.com devnull4@socialtext.com ) ) {
        my $user = Socialtext::User->new( username => $username );

        ok( $user, "$username exists in database" );
        ok( $ws->has_user( user => $user ),
            "$username is a member of the admin workspace" );
        is( $user->creator()->username(), 'devnull1@socialtext.com',
            "$username has devnull1\@socialtext.com as creator" );
    }
}
